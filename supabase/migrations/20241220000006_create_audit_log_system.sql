-- Create audit log table for comprehensive change tracking
CREATE TABLE public.audit_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  entity_type TEXT NOT NULL, -- 'user_profiles', 'lists', 'tasks', 'custom_field_definitions'
  entity_id UUID NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('create', 'update', 'delete')),
  old_values JSONB, -- Previous values (NULL for create)
  new_values JSONB, -- New values (NULL for delete)
  changed_fields TEXT[], -- Array of field names that changed (for updates)
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  user_agent TEXT, -- Browser/client information
  ip_address INET, -- Client IP address
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  
  -- Ensure we have values for the appropriate actions
  CONSTRAINT audit_create_has_new_values CHECK (
    action != 'create' OR new_values IS NOT NULL
  ),
  CONSTRAINT audit_delete_has_old_values CHECK (
    action != 'delete' OR old_values IS NOT NULL
  ),
  CONSTRAINT audit_update_has_both_values CHECK (
    action != 'update' OR (old_values IS NOT NULL AND new_values IS NOT NULL)
  )
);

-- Create indexes for efficient audit log queries
CREATE INDEX idx_audit_logs_entity_type ON public.audit_logs(entity_type);
CREATE INDEX idx_audit_logs_entity_id ON public.audit_logs(entity_id);
CREATE INDEX idx_audit_logs_action ON public.audit_logs(action);
CREATE INDEX idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON public.audit_logs(created_at);

-- Create composite indexes for common queries
CREATE INDEX idx_audit_logs_entity_type_id ON public.audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_user_created ON public.audit_logs(user_id, created_at);
CREATE INDEX idx_audit_logs_entity_created ON public.audit_logs(entity_type, created_at);

-- Create GIN index for searching within JSONB values
CREATE INDEX idx_audit_logs_old_values ON public.audit_logs USING GIN(old_values);
CREATE INDEX idx_audit_logs_new_values ON public.audit_logs USING GIN(new_values);

-- Enable Row Level Security
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view audit logs for entities they have access to
CREATE POLICY "Users can view accessible audit logs" ON public.audit_logs
  FOR SELECT USING (
    -- Users can see their own actions
    auth.uid() = user_id OR
    -- Users can see audit logs for tasks they have access to
    (entity_type = 'tasks' AND EXISTS (
      SELECT 1 FROM public.tasks t
      WHERE t.id = entity_id
        AND (t.owner_id = auth.uid() OR t.assigned_to = auth.uid() OR
             EXISTS (SELECT 1 FROM public.lists l WHERE l.id = t.list_id AND l.owner_id = auth.uid()))
    )) OR
    -- Users can see audit logs for lists they own
    (entity_type = 'lists' AND EXISTS (
      SELECT 1 FROM public.lists l
      WHERE l.id = entity_id AND l.owner_id = auth.uid()
    )) OR
    -- Users can see audit logs for their own profile
    (entity_type = 'user_profiles' AND entity_id = auth.uid()) OR
    -- Users can see audit logs for their own custom field definitions
    (entity_type = 'custom_field_definitions' AND EXISTS (
      SELECT 1 FROM public.custom_field_definitions cfd
      WHERE cfd.id = entity_id AND cfd.owner_id = auth.uid()
    ))
  );

-- Audit logs are immutable - no insert, update, or delete policies for regular users
-- Only the system can create audit logs through triggers

-- Generic audit trigger function
CREATE OR REPLACE FUNCTION public.audit_trigger()
RETURNS TRIGGER AS $$
DECLARE
  old_data JSONB;
  new_data JSONB;
  changed_fields TEXT[] := '{}';
  field_name TEXT;
BEGIN
  -- Determine the action
  IF TG_OP = 'DELETE' THEN
    old_data := to_jsonb(OLD);
    new_data := NULL;
  ELSIF TG_OP = 'INSERT' THEN
    old_data := NULL;
    new_data := to_jsonb(NEW);
  ELSIF TG_OP = 'UPDATE' THEN
    old_data := to_jsonb(OLD);
    new_data := to_jsonb(NEW);
    
    -- Determine which fields changed
    FOR field_name IN SELECT jsonb_object_keys(new_data) LOOP
      IF old_data -> field_name IS DISTINCT FROM new_data -> field_name THEN
        changed_fields := array_append(changed_fields, field_name);
      END IF;
    END LOOP;
  END IF;

  -- Insert audit log entry
  INSERT INTO public.audit_logs (
    entity_type,
    entity_id,
    action,
    old_values,
    new_values,
    changed_fields,
    user_id,
    user_agent,
    ip_address
  ) VALUES (
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    LOWER(TG_OP),
    old_data,
    new_data,
    CASE WHEN TG_OP = 'UPDATE' THEN changed_fields ELSE NULL END,
    auth.uid(),
    current_setting('request.headers', true)::json->>'user-agent',
    inet_client_addr()
  );

  -- Return the appropriate record
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add audit triggers to all main tables
CREATE TRIGGER audit_user_profiles_trigger
  AFTER INSERT OR UPDATE OR DELETE ON public.user_profiles
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();

CREATE TRIGGER audit_lists_trigger
  AFTER INSERT OR UPDATE OR DELETE ON public.lists
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();

CREATE TRIGGER audit_tasks_trigger
  AFTER INSERT OR UPDATE OR DELETE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();

CREATE TRIGGER audit_custom_field_definitions_trigger
  AFTER INSERT OR UPDATE OR DELETE ON public.custom_field_definitions
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();

-- Function to get audit history for a specific entity
CREATE OR REPLACE FUNCTION public.get_audit_history(
  entity_type_param TEXT,
  entity_id_param UUID,
  limit_param INTEGER DEFAULT 50
) RETURNS TABLE(
  id UUID,
  action TEXT,
  old_values JSONB,
  new_values JSONB,
  changed_fields TEXT[],
  user_id UUID,
  user_email TEXT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    al.id,
    al.action,
    al.old_values,
    al.new_values,
    al.changed_fields,
    al.user_id,
    au.email as user_email,
    al.created_at
  FROM public.audit_logs al
  LEFT JOIN auth.users au ON al.user_id = au.id
  WHERE al.entity_type = entity_type_param
    AND al.entity_id = entity_id_param
  ORDER BY al.created_at DESC
  LIMIT limit_param;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Function to get recent activity for a user
CREATE OR REPLACE FUNCTION public.get_user_activity(
  user_uuid UUID DEFAULT auth.uid(),
  limit_param INTEGER DEFAULT 20
) RETURNS TABLE(
  id UUID,
  entity_type TEXT,
  entity_id UUID,
  action TEXT,
  entity_title TEXT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    al.id,
    al.entity_type,
    al.entity_id,
    al.action,
    CASE 
      WHEN al.entity_type = 'tasks' THEN al.new_values->>'title'
      WHEN al.entity_type = 'lists' THEN al.new_values->>'title'
      WHEN al.entity_type = 'custom_field_definitions' THEN al.new_values->>'name'
      WHEN al.entity_type = 'user_profiles' THEN al.new_values->>'display_name'
      ELSE 'Unknown'
    END as entity_title,
    al.created_at
  FROM public.audit_logs al
  WHERE al.user_id = user_uuid
  ORDER BY al.created_at DESC
  LIMIT limit_param;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Function to get audit statistics
CREATE OR REPLACE FUNCTION public.get_audit_statistics(
  start_date TIMESTAMPTZ DEFAULT NOW() - INTERVAL '30 days',
  end_date TIMESTAMPTZ DEFAULT NOW()
) RETURNS TABLE(
  entity_type TEXT,
  action TEXT,
  count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    al.entity_type,
    al.action,
    COUNT(*) as count
  FROM public.audit_logs al
  WHERE al.created_at BETWEEN start_date AND end_date
    AND (
      -- Only show stats for entities the user has access to
      al.user_id = auth.uid() OR
      (al.entity_type = 'tasks' AND EXISTS (
        SELECT 1 FROM public.tasks t
        WHERE t.id = al.entity_id
          AND (t.owner_id = auth.uid() OR t.assigned_to = auth.uid() OR
               EXISTS (SELECT 1 FROM public.lists l WHERE l.id = t.list_id AND l.owner_id = auth.uid()))
      )) OR
      (al.entity_type = 'lists' AND EXISTS (
        SELECT 1 FROM public.lists l
        WHERE l.id = al.entity_id AND l.owner_id = auth.uid()
      )) OR
      (al.entity_type = 'user_profiles' AND al.entity_id = auth.uid()) OR
      (al.entity_type = 'custom_field_definitions' AND EXISTS (
        SELECT 1 FROM public.custom_field_definitions cfd
        WHERE cfd.id = al.entity_id AND cfd.owner_id = auth.uid()
      ))
    )
  GROUP BY al.entity_type, al.action
  ORDER BY al.entity_type, al.action;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;