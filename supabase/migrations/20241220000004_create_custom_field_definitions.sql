-- Create custom field definitions table
CREATE TABLE public.custom_field_definitions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  field_type TEXT NOT NULL CHECK (field_type IN ('text', 'number', 'date', 'boolean', 'select')),
  entity_type TEXT NOT NULL CHECK (entity_type IN ('task', 'list')),
  options JSONB, -- For select fields: {"options": ["option1", "option2"]}
  required BOOLEAN DEFAULT FALSE NOT NULL,
  default_value JSONB, -- Default value for the field
  validation_rules JSONB, -- Additional validation rules like min/max for numbers
  description TEXT, -- Help text for the field
  owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  
  -- Ensure unique field names per entity type per owner
  CONSTRAINT unique_field_name_per_entity_owner UNIQUE (name, entity_type, owner_id)
);

-- Add updated_at trigger to custom_field_definitions table
CREATE TRIGGER handle_custom_field_definitions_updated_at
  BEFORE UPDATE ON public.custom_field_definitions
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Create indexes for efficient queries
CREATE INDEX idx_custom_field_definitions_owner_id ON public.custom_field_definitions(owner_id);
CREATE INDEX idx_custom_field_definitions_entity_type ON public.custom_field_definitions(entity_type);
CREATE INDEX idx_custom_field_definitions_field_type ON public.custom_field_definitions(field_type);

-- Create composite index for common queries
CREATE INDEX idx_custom_field_definitions_owner_entity ON public.custom_field_definitions(owner_id, entity_type);

-- Enable Row Level Security
ALTER TABLE public.custom_field_definitions ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own custom field definitions
CREATE POLICY "Users can view own custom field definitions" ON public.custom_field_definitions
  FOR SELECT USING (auth.uid() = owner_id);

-- RLS Policy: Users can insert their own custom field definitions
CREATE POLICY "Users can insert own custom field definitions" ON public.custom_field_definitions
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

-- RLS Policy: Users can update their own custom field definitions
CREATE POLICY "Users can update own custom field definitions" ON public.custom_field_definitions
  FOR UPDATE USING (auth.uid() = owner_id);

-- RLS Policy: Users can delete their own custom field definitions
CREATE POLICY "Users can delete own custom field definitions" ON public.custom_field_definitions
  FOR DELETE USING (auth.uid() = owner_id);

-- Function to validate custom field value against its definition
CREATE OR REPLACE FUNCTION public.validate_custom_field_value(
  field_definition_id UUID,
  field_value JSONB
) RETURNS BOOLEAN AS $$
DECLARE
  definition RECORD;
  value_text TEXT;
  value_number NUMERIC;
  value_date DATE;
  value_boolean BOOLEAN;
  option_exists BOOLEAN;
  min_val NUMERIC;
  max_val NUMERIC;
  min_length INTEGER;
  max_length INTEGER;
BEGIN
  -- Get the field definition
  SELECT * INTO definition
  FROM public.custom_field_definitions
  WHERE id = field_definition_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Custom field definition not found: %', field_definition_id;
  END IF;
  
  -- Handle null values
  IF field_value IS NULL OR field_value = 'null'::jsonb THEN
    RETURN NOT definition.required;
  END IF;
  
  -- Validate based on field type
  CASE definition.field_type
    WHEN 'text' THEN
      -- Extract text value
      value_text := field_value #>> '{}';
      
      -- Check required
      IF definition.required AND (value_text IS NULL OR value_text = '') THEN
        RETURN FALSE;
      END IF;
      
      -- Check length constraints if specified
      IF definition.validation_rules IS NOT NULL THEN
        min_length := (definition.validation_rules ->> 'min_length')::INTEGER;
        max_length := (definition.validation_rules ->> 'max_length')::INTEGER;
        
        IF min_length IS NOT NULL AND LENGTH(value_text) < min_length THEN
          RETURN FALSE;
        END IF;
        
        IF max_length IS NOT NULL AND LENGTH(value_text) > max_length THEN
          RETURN FALSE;
        END IF;
      END IF;
      
    WHEN 'number' THEN
      -- Extract numeric value
      BEGIN
        value_number := (field_value #>> '{}')::NUMERIC;
      EXCEPTION WHEN OTHERS THEN
        RETURN FALSE;
      END;
      
      -- Check min/max constraints if specified
      IF definition.validation_rules IS NOT NULL THEN
        min_val := (definition.validation_rules ->> 'min')::NUMERIC;
        max_val := (definition.validation_rules ->> 'max')::NUMERIC;
        
        IF min_val IS NOT NULL AND value_number < min_val THEN
          RETURN FALSE;
        END IF;
        
        IF max_val IS NOT NULL AND value_number > max_val THEN
          RETURN FALSE;
        END IF;
      END IF;
      
    WHEN 'date' THEN
      -- Extract date value
      BEGIN
        value_date := (field_value #>> '{}')::DATE;
      EXCEPTION WHEN OTHERS THEN
        RETURN FALSE;
      END;
      
    WHEN 'boolean' THEN
      -- Extract boolean value
      BEGIN
        value_boolean := (field_value #>> '{}')::BOOLEAN;
      EXCEPTION WHEN OTHERS THEN
        RETURN FALSE;
      END;
      
    WHEN 'select' THEN
      -- Extract text value for select
      value_text := field_value #>> '{}';
      
      -- Check if value exists in options
      IF definition.options IS NOT NULL THEN
        SELECT EXISTS(
          SELECT 1 FROM jsonb_array_elements_text(definition.options -> 'options') AS option
          WHERE option = value_text
        ) INTO option_exists;
        
        IF NOT option_exists THEN
          RETURN FALSE;
        END IF;
      END IF;
      
    ELSE
      RAISE EXCEPTION 'Unknown field type: %', definition.field_type;
  END CASE;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to validate all custom fields in a JSONB object
CREATE OR REPLACE FUNCTION public.validate_custom_fields(
  custom_fields JSONB,
  entity_type TEXT,
  owner_uuid UUID
) RETURNS BOOLEAN AS $$
DECLARE
  field_name TEXT;
  field_value JSONB;
  definition_id UUID;
BEGIN
  -- Iterate through each custom field
  FOR field_name, field_value IN SELECT * FROM jsonb_each(custom_fields) LOOP
    -- Find the field definition
    SELECT id INTO definition_id
    FROM public.custom_field_definitions
    WHERE name = field_name 
      AND entity_type = validate_custom_fields.entity_type
      AND owner_id = owner_uuid;
    
    -- If definition not found, field is invalid
    IF definition_id IS NULL THEN
      RAISE EXCEPTION 'Custom field definition not found: % for entity type: %', field_name, entity_type;
    END IF;
    
    -- Validate the field value
    IF NOT public.validate_custom_field_value(definition_id, field_value) THEN
      RAISE EXCEPTION 'Invalid value for custom field: %', field_name;
    END IF;
  END LOOP;
  
  -- Check for required fields that are missing
  IF EXISTS (
    SELECT 1 FROM public.custom_field_definitions cfd
    WHERE cfd.entity_type = validate_custom_fields.entity_type
      AND cfd.owner_id = owner_uuid
      AND cfd.required = TRUE
      AND NOT (custom_fields ? cfd.name)
  ) THEN
    RAISE EXCEPTION 'Required custom fields are missing';
  END IF;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get custom field schema for an entity type
CREATE OR REPLACE FUNCTION public.get_custom_field_schema(
  entity_type TEXT,
  owner_uuid UUID DEFAULT auth.uid()
) RETURNS TABLE(
  id UUID,
  name TEXT,
  field_type TEXT,
  required BOOLEAN,
  options JSONB,
  default_value JSONB,
  validation_rules JSONB,
  description TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cfd.id,
    cfd.name,
    cfd.field_type,
    cfd.required,
    cfd.options,
    cfd.default_value,
    cfd.validation_rules,
    cfd.description
  FROM public.custom_field_definitions cfd
  WHERE cfd.entity_type = get_custom_field_schema.entity_type
    AND cfd.owner_id = owner_uuid
  ORDER BY cfd.name;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Function to apply default values to custom fields
CREATE OR REPLACE FUNCTION public.apply_custom_field_defaults(
  custom_fields JSONB,
  entity_type TEXT,
  owner_uuid UUID
) RETURNS JSONB AS $$
DECLARE
  result JSONB := custom_fields;
  definition RECORD;
BEGIN
  -- Apply defaults for missing fields
  FOR definition IN 
    SELECT name, default_value
    FROM public.custom_field_definitions
    WHERE entity_type = apply_custom_field_defaults.entity_type
      AND owner_id = owner_uuid
      AND default_value IS NOT NULL
      AND NOT (custom_fields ? name)
  LOOP
    result := result || jsonb_build_object(definition.name, definition.default_value);
  END LOOP;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql STABLE;