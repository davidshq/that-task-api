-- Test script to verify custom field definitions and validation
-- This can be run in Supabase Studio or via psql

-- Check if table exists and has correct structure
SELECT 
  column_name, 
  data_type, 
  is_nullable, 
  column_default
FROM information_schema.columns 
WHERE table_name = 'custom_field_definitions' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check if RLS is enabled
SELECT 
  schemaname, 
  tablename, 
  rowsecurity 
FROM pg_tables 
WHERE tablename = 'custom_field_definitions';

-- Check RLS policies
SELECT 
  policyname, 
  permissive, 
  roles, 
  cmd, 
  qual, 
  with_check
FROM pg_policies 
WHERE tablename = 'custom_field_definitions';

-- Check indexes
SELECT 
  indexname, 
  indexdef
FROM pg_indexes 
WHERE tablename = 'custom_field_definitions' 
  AND schemaname = 'public'
ORDER BY indexname;

-- Check triggers on custom_field_definitions
SELECT 
  trigger_name, 
  event_manipulation, 
  action_timing, 
  action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'custom_field_definitions';

-- Check validation triggers on tasks and lists
SELECT 
  event_object_table,
  trigger_name, 
  event_manipulation, 
  action_timing
FROM information_schema.triggers 
WHERE trigger_name LIKE '%custom_field%'
ORDER BY event_object_table, trigger_name;

-- Check custom field related functions exist
SELECT 
  routine_name, 
  routine_type, 
  data_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND (routine_name LIKE '%custom_field%' OR routine_name LIKE '%validate%')
ORDER BY routine_name;

-- Check constraints
SELECT 
  constraint_name,
  constraint_type,
  check_clause
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.check_constraints cc 
  ON tc.constraint_name = cc.constraint_name
WHERE tc.table_name = 'custom_field_definitions' 
  AND tc.table_schema = 'public';

-- Example usage (would need valid user ID):
-- 
-- -- Create a custom field definition
-- INSERT INTO public.custom_field_definitions (
--   name, field_type, entity_type, required, owner_id, description
-- ) VALUES (
--   'priority_score', 'number', 'task', false, 'user-uuid', 'Numeric priority score from 1-10'
-- );
--
-- -- Create a select field with options
-- INSERT INTO public.custom_field_definitions (
--   name, field_type, entity_type, options, owner_id, description
-- ) VALUES (
--   'department', 'select', 'list', 
--   '{"options": ["Engineering", "Marketing", "Sales", "Support"]}',
--   'user-uuid', 'Department classification'
-- );
--
-- -- Test validation function
-- SELECT public.validate_custom_field_value(
--   'field-definition-uuid',
--   '"Engineering"'::jsonb
-- );
--
-- -- Get custom field schema
-- SELECT * FROM public.get_custom_field_schema('task', 'user-uuid');