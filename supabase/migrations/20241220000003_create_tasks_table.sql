-- Create tasks table with rich metadata
CREATE TABLE public.tasks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  parent_id UUID REFERENCES public.tasks(id) ON DELETE CASCADE,
  list_id UUID REFERENCES public.lists(id) ON DELETE CASCADE,
  owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  assigned_to UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  status TEXT DEFAULT 'todo' CHECK (status IN ('todo', 'in_progress', 'done', 'cancelled')),
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  due_date TIMESTAMPTZ,
  tags TEXT[] DEFAULT '{}' NOT NULL,
  custom_fields JSONB DEFAULT '{}' NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  
  -- Prevent self-referencing
  CONSTRAINT no_self_reference CHECK (id != parent_id),
  
  -- Ensure task has either a list or a parent task (but can have both)
  CONSTRAINT has_list_or_parent CHECK (list_id IS NOT NULL OR parent_id IS NOT NULL)
);

-- Add updated_at trigger to tasks table
CREATE TRIGGER handle_tasks_updated_at
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Create indexes for efficient queries
CREATE INDEX idx_tasks_parent_id ON public.tasks(parent_id);
CREATE INDEX idx_tasks_list_id ON public.tasks(list_id);
CREATE INDEX idx_tasks_owner_id ON public.tasks(owner_id);
CREATE INDEX idx_tasks_assigned_to ON public.tasks(assigned_to);
CREATE INDEX idx_tasks_status ON public.tasks(status);
CREATE INDEX idx_tasks_priority ON public.tasks(priority);
CREATE INDEX idx_tasks_due_date ON public.tasks(due_date);
CREATE INDEX idx_tasks_created_at ON public.tasks(created_at);

-- Create composite indexes for common queries
CREATE INDEX idx_tasks_owner_status ON public.tasks(owner_id, status);
CREATE INDEX idx_tasks_list_status ON public.tasks(list_id, status);
CREATE INDEX idx_tasks_assigned_status ON public.tasks(assigned_to, status);
CREATE INDEX idx_tasks_due_status ON public.tasks(due_date, status) WHERE due_date IS NOT NULL;

-- Create GIN index for tags array queries
CREATE INDEX idx_tasks_tags ON public.tasks USING GIN(tags);

-- Create GIN index for custom_fields JSONB queries
CREATE INDEX idx_tasks_custom_fields ON public.tasks USING GIN(custom_fields);

-- Enable Row Level Security
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view tasks they own or are assigned to, or tasks in lists they own
CREATE POLICY "Users can view accessible tasks" ON public.tasks
  FOR SELECT USING (
    auth.uid() = owner_id OR 
    auth.uid() = assigned_to OR
    EXISTS (
      SELECT 1 FROM public.lists 
      WHERE lists.id = tasks.list_id 
      AND lists.owner_id = auth.uid()
    )
  );

-- RLS Policy: Users can insert tasks they own
CREATE POLICY "Users can insert own tasks" ON public.tasks
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

-- RLS Policy: Users can update tasks they own or tasks in lists they own
CREATE POLICY "Users can update accessible tasks" ON public.tasks
  FOR UPDATE USING (
    auth.uid() = owner_id OR
    EXISTS (
      SELECT 1 FROM public.lists 
      WHERE lists.id = tasks.list_id 
      AND lists.owner_id = auth.uid()
    )
  );

-- RLS Policy: Users can delete tasks they own or tasks in lists they own
CREATE POLICY "Users can delete accessible tasks" ON public.tasks
  FOR DELETE USING (
    auth.uid() = owner_id OR
    EXISTS (
      SELECT 1 FROM public.lists 
      WHERE lists.id = tasks.list_id 
      AND lists.owner_id = auth.uid()
    )
  );

-- Function to prevent circular references in task hierarchy
CREATE OR REPLACE FUNCTION public.check_task_hierarchy()
RETURNS TRIGGER AS $$
DECLARE
  ancestor_id UUID;
BEGIN
  -- If no parent, no circular reference possible
  IF NEW.parent_id IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Check if the new parent would create a circular reference
  -- by walking up the hierarchy from the proposed parent
  ancestor_id := NEW.parent_id;
  
  WHILE ancestor_id IS NOT NULL LOOP
    -- If we find our own ID in the ancestry, it's circular
    IF ancestor_id = NEW.id THEN
      RAISE EXCEPTION 'Circular reference detected: task cannot be its own ancestor';
    END IF;
    
    -- Move up one level
    SELECT parent_id INTO ancestor_id 
    FROM public.tasks 
    WHERE id = ancestor_id;
  END LOOP;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger to check for circular references
CREATE TRIGGER check_task_hierarchy_trigger
  BEFORE INSERT OR UPDATE ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.check_task_hierarchy();

-- Function to inherit list_id from parent task if not specified
CREATE OR REPLACE FUNCTION public.inherit_task_list()
RETURNS TRIGGER AS $$
BEGIN
  -- If list_id is not provided but parent_id is, inherit from parent
  IF NEW.list_id IS NULL AND NEW.parent_id IS NOT NULL THEN
    SELECT list_id INTO NEW.list_id
    FROM public.tasks
    WHERE id = NEW.parent_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger to inherit list from parent
CREATE TRIGGER inherit_task_list_trigger
  BEFORE INSERT ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.inherit_task_list();

-- Function to get task hierarchy path (breadcrumb)
CREATE OR REPLACE FUNCTION public.get_task_path(task_uuid UUID)
RETURNS TEXT[] AS $$
WITH RECURSIVE path AS (
  -- Base case: start with the target task
  SELECT id, title, parent_id, ARRAY[title] as path, 1 as level
  FROM public.tasks 
  WHERE id = task_uuid
  
  UNION ALL
  
  -- Recursive case: add parent to path
  SELECT t.id, t.title, t.parent_id, t.title || p.path, p.level + 1
  FROM public.tasks t 
  JOIN path p ON t.id = p.parent_id
  WHERE p.level < 50 -- Prevent infinite recursion
)
SELECT path 
FROM path 
WHERE parent_id IS NULL
ORDER BY level DESC
LIMIT 1;
$$ LANGUAGE SQL STABLE;

-- Function to get all subtasks of a task
CREATE OR REPLACE FUNCTION public.get_task_subtasks(task_uuid UUID)
RETURNS TABLE(id UUID, title TEXT, status TEXT, level INTEGER) AS $$
WITH RECURSIVE subtasks AS (
  -- Base case: start with the target task
  SELECT t.id, t.title, t.status, t.parent_id, 0 as level
  FROM public.tasks t
  WHERE t.id = task_uuid
  
  UNION ALL
  
  -- Recursive case: find children
  SELECT t.id, t.title, t.status, t.parent_id, s.level + 1
  FROM public.tasks t
  JOIN subtasks s ON t.parent_id = s.id
  WHERE s.level < 50 -- Prevent infinite recursion
)
SELECT subtasks.id, subtasks.title, subtasks.status, subtasks.level
FROM subtasks
WHERE subtasks.level > 0 -- Exclude the root task itself
ORDER BY subtasks.level, subtasks.title;
$$ LANGUAGE SQL STABLE;

-- Function to get task completion percentage based on subtasks
CREATE OR REPLACE FUNCTION public.get_task_completion_percentage(task_uuid UUID)
RETURNS NUMERIC AS $$
DECLARE
  total_subtasks INTEGER;
  completed_subtasks INTEGER;
BEGIN
  -- Count total direct subtasks
  SELECT COUNT(*) INTO total_subtasks
  FROM public.tasks
  WHERE parent_id = task_uuid;
  
  -- If no subtasks, return NULL (completion is based on task status itself)
  IF total_subtasks = 0 THEN
    RETURN NULL;
  END IF;
  
  -- Count completed subtasks
  SELECT COUNT(*) INTO completed_subtasks
  FROM public.tasks
  WHERE parent_id = task_uuid AND status = 'done';
  
  -- Return percentage
  RETURN ROUND((completed_subtasks::NUMERIC / total_subtasks::NUMERIC) * 100, 2);
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get overdue tasks
CREATE OR REPLACE FUNCTION public.get_overdue_tasks(user_uuid UUID DEFAULT auth.uid())
RETURNS TABLE(
  id UUID, 
  title TEXT, 
  due_date TIMESTAMPTZ, 
  days_overdue INTEGER,
  priority TEXT,
  list_title TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.id,
    t.title,
    t.due_date,
    EXTRACT(DAY FROM NOW() - t.due_date)::INTEGER as days_overdue,
    t.priority,
    l.title as list_title
  FROM public.tasks t
  LEFT JOIN public.lists l ON t.list_id = l.id
  WHERE t.due_date < NOW()
    AND t.status NOT IN ('done', 'cancelled')
    AND (t.owner_id = user_uuid OR t.assigned_to = user_uuid)
  ORDER BY t.due_date ASC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;