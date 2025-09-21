-- Test script to verify lists table and hierarchical functionality
-- This can be run in Supabase Studio or via psql

-- Check if table exists and has correct structure
SELECT 
  column_name, 
  data_type, 
  is_nullable, 
  column_default
FROM information_schema.columns 
WHERE table_name = 'lists' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check if RLS is enabled
SELECT 
  schemaname, 
  tablename, 
  rowsecurity 
FROM pg_tables 
WHERE tablename = 'lists';

-- Check RLS policies
SELECT 
  policyname, 
  permissive, 
  roles, 
  cmd, 
  qual, 
  with_check
FROM pg_policies 
WHERE tablename = 'lists';

-- Check indexes
SELECT 
  indexname, 
  indexdef
FROM pg_indexes 
WHERE tablename = 'lists' 
  AND schemaname = 'public';

-- Check triggers
SELECT 
  trigger_name, 
  event_manipulation, 
  action_timing, 
  action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'lists';

-- Check functions exist
SELECT 
  routine_name, 
  routine_type, 
  data_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE '%list%'
ORDER BY routine_name;

-- Test hierarchical functions (these would need actual data to test properly)
-- Example usage:
-- SELECT * FROM public.get_list_path('some-uuid');
-- SELECT * FROM public.get_list_descendants('some-uuid');
-- SELECT * FROM public.get_list_ancestors('some-uuid');