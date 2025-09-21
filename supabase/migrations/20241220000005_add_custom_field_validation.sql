-- Add custom field validation triggers to tasks and lists tables

-- Function to validate custom fields on tasks
CREATE OR REPLACE FUNCTION public.validate_task_custom_fields()
RETURNS TRIGGER AS $$
BEGIN
  -- Apply defaults first
  NEW.custom_fields := public.apply_custom_field_defaults(
    NEW.custom_fields, 
    'task', 
    NEW.owner_id
  );
  
  -- Validate custom fields
  PERFORM public.validate_custom_fields(
    NEW.custom_fields, 
    'task', 
    NEW.owner_id
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to validate custom fields on lists
CREATE OR REPLACE FUNCTION public.validate_list_custom_fields()
RETURNS TRIGGER AS $$
BEGIN
  -- Apply defaults first
  NEW.custom_fields := public.apply_custom_field_defaults(
    NEW.custom_fields, 
    'list', 
    NEW.owner_id
  );
  
  -- Validate custom fields
  PERFORM public.validate_custom_fields(
    NEW.custom_fields, 
    'list', 
    NEW.owner_id
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add validation triggers to tasks table
CREATE TRIGGER validate_task_custom_fields_trigger
  BEFORE INSERT OR UPDATE ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_task_custom_fields();

-- Add validation triggers to lists table
CREATE TRIGGER validate_list_custom_fields_trigger
  BEFORE INSERT OR UPDATE ON public.lists
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_list_custom_fields();

-- Function to clean up custom fields when definition is deleted
CREATE OR REPLACE FUNCTION public.cleanup_custom_fields_on_definition_delete()
RETURNS TRIGGER AS $$
BEGIN
  -- Remove the custom field from all tasks if it's a task field
  IF OLD.entity_type = 'task' THEN
    UPDATE public.tasks 
    SET custom_fields = custom_fields - OLD.name
    WHERE owner_id = OLD.owner_id
      AND custom_fields ? OLD.name;
  END IF;
  
  -- Remove the custom field from all lists if it's a list field
  IF OLD.entity_type = 'list' THEN
    UPDATE public.lists 
    SET custom_fields = custom_fields - OLD.name
    WHERE owner_id = OLD.owner_id
      AND custom_fields ? OLD.name;
  END IF;
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Add cleanup trigger to custom field definitions
CREATE TRIGGER cleanup_custom_fields_on_definition_delete_trigger
  AFTER DELETE ON public.custom_field_definitions
  FOR EACH ROW
  EXECUTE FUNCTION public.cleanup_custom_fields_on_definition_delete();