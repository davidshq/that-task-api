-- Test script to verify tasks table and functionality
-- This can be run in Supabase Studio or via psql

-- Check if table exists and has correct structure
SELECT 
  column_name, 
  data_type, 
  is_nullable, 
  column_default
FROM information_schema.columns 
WHERE table_name = 'tasks' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check if RLS is enabled
SELECT 
  schemaname, 
  tablename, 
  rowsecurity 
FROM pg_tables 
WHERE tablename = 'tasks';

-- Check RLS policies
SELECT 
  policyname, 
  permissive, 
  roles, 
  cmd, 
  qual, 
  with_check
FROM pg_policies 
WHERE tablename = 'tasks';

-- Check indexes
SELECT 
  indexname, 
  indexdef
FROM pg_indexes 
WHERE tablename = 'tasks' 
  AND schemaname = 'public'
ORDER BY indexname;

-- Check triggers
SELECT 
  trigger_name, 
  event_manipulation, 
  action_timing, 
  action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'tasks';

-- Check task-related functions exist
SELECT 
  routine_name, 
  routine_type, 
  data_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE '%task%'
ORDER BY routine_name;

-- Check constraints
SELECT 
  constraint_name,
  constraint_type,
  check_clause
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.check_constraints cc 
  ON tc.constraint_name = cc.constraint_name
WHERE tc.table_name = 'tasks' 
  AND tc.table_schema = 'public';

-- Test hierarchical functions (these would need actual data to test properly)
-- Example usage:
-- SELECT * FROM public.get_task_path('some-uuid');
-- SELECT * FROM public.get_task_subtasks('some-uuid');
-- SELECT * FROM public.get_task_completion_percentage('some-uuid');
-- SELECT * FROM public.get_overdue_tasks();

-- Sample data insertion test (would need valid user and list IDs)
-- INSERT INTO public.tasks (title, description, owner_id, status, priority, tags)
-- VALUES ('Test Task', 'A test task', 'user-uuid', 'todo', 'medium', ARRAY['test', 'sample']);