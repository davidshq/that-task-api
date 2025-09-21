-- Test script to verify audit log system
-- This can be run in Supabase Studio or via psql

-- Check if audit_logs table exists and has correct structure
SELECT 
  column_name, 
  data_type, 
  is_nullable, 
  column_default
FROM information_schema.columns 
WHERE table_name = 'audit_logs' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check if RLS is enabled
SELECT 
  schemaname, 
  tablename, 
  rowsecurity 
FROM pg_tables 
WHERE tablename = 'audit_logs';

-- Check RLS policies
SELECT 
  policyname, 
  permissive, 
  roles, 
  cmd, 
  qual, 
  with_check
FROM pg_policies 
WHERE tablename = 'audit_logs';

-- Check indexes
SELECT 
  indexname, 
  indexdef
FROM pg_indexes 
WHERE tablename = 'audit_logs' 
  AND schemaname = 'public'
ORDER BY indexname;

-- Check audit triggers on all tables
SELECT 
  event_object_table,
  trigger_name, 
  event_manipulation, 
  action_timing,
  action_statement
FROM information_schema.triggers 
WHERE trigger_name LIKE '%audit%'
ORDER BY event_object_table, trigger_name;

-- Check audit-related functions exist
SELECT 
  routine_name, 
  routine_type, 
  data_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND (routine_name LIKE '%audit%' OR routine_name = 'get_user_activity')
ORDER BY routine_name;

-- Check constraints
SELECT 
  constraint_name,
  constraint_type,
  check_clause
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.check_constraints cc 
  ON tc.constraint_name = cc.constraint_name
WHERE tc.table_name = 'audit_logs' 
  AND tc.table_schema = 'public';

-- Example usage (would need valid user and entity IDs):
-- 
-- -- View audit history for a specific task
-- SELECT * FROM public.get_audit_history('tasks', 'task-uuid', 10);
--
-- -- View recent user activity
-- SELECT * FROM public.get_user_activity('user-uuid', 20);
--
-- -- View audit statistics for the last 30 days
-- SELECT * FROM public.get_audit_statistics();
--
-- -- Test audit logging by creating/updating/deleting entities
-- -- (These operations would automatically create audit log entries)
--
-- -- Create a test list (would create audit log entry)
-- INSERT INTO public.lists (title, owner_id) 
-- VALUES ('Test List', 'user-uuid');
--
-- -- Update the list (would create audit log entry)
-- UPDATE public.lists 
-- SET description = 'Updated description' 
-- WHERE title = 'Test List' AND owner_id = 'user-uuid';
--
-- -- Delete the list (would create audit log entry)
-- DELETE FROM public.lists 
-- WHERE title = 'Test List' AND owner_id = 'user-uuid';
--
-- -- View the audit trail
-- SELECT 
--   action,
--   old_values->>'title' as old_title,
--   new_values->>'title' as new_title,
--   changed_fields,
--   created_at
-- FROM public.audit_logs 
-- WHERE entity_type = 'lists'
-- ORDER BY created_at DESC;