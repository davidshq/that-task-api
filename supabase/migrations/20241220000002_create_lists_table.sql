-- Create lists table with hierarchical support
CREATE TABLE public.lists (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  parent_id UUID REFERENCES public.lists(id) ON DELETE CASCADE,
  owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type TEXT DEFAULT 'list' CHECK (type IN ('list', 'project', 'workspace', 'folder')),
  custom_fields JSONB DEFAULT '{}' NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  
  -- Prevent self-referencing and circular references at database level
  CONSTRAINT no_self_reference CHECK (id != parent_id)
);

-- Add updated_at trigger to lists table
CREATE TRIGGER handle_lists_updated_at
  BEFORE UPDATE ON public.lists
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Create indexes for efficient hierarchical queries
CREATE INDEX idx_lists_parent_id ON public.lists(parent_id);
CREATE INDEX idx_lists_owner_id ON public.lists(owner_id);
CREATE INDEX idx_lists_type ON public.lists(type);
CREATE INDEX idx_lists_created_at ON public.lists(created_at);

-- Create composite index for common queries
CREATE INDEX idx_lists_owner_parent ON public.lists(owner_id, parent_id);

-- Enable Row Level Security
ALTER TABLE public.lists ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view lists they own
CREATE POLICY "Users can view owned lists" ON public.lists
  FOR SELECT USING (auth.uid() = owner_id);

-- RLS Policy: Users can insert lists they own
CREATE POLICY "Users can insert own lists" ON public.lists
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

-- RLS Policy: Users can update lists they own
CREATE POLICY "Users can update owned lists" ON public.lists
  FOR UPDATE USING (auth.uid() = owner_id);

-- RLS Policy: Users can delete lists they own
CREATE POLICY "Users can delete owned lists" ON public.lists
  FOR DELETE USING (auth.uid() = owner_id);

-- Function to prevent circular references in list hierarchy
CREATE OR REPLACE FUNCTION public.check_list_hierarchy()
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
      RAISE EXCEPTION 'Circular reference detected: list cannot be its own ancestor';
    END IF;
    
    -- Move up one level
    SELECT parent_id INTO ancestor_id 
    FROM public.lists 
    WHERE id = ancestor_id;
  END LOOP;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger to check for circular references
CREATE TRIGGER check_list_hierarchy_trigger
  BEFORE INSERT OR UPDATE ON public.lists
  FOR EACH ROW
  EXECUTE FUNCTION public.check_list_hierarchy();

-- Function to get list hierarchy path (breadcrumb)
CREATE OR REPLACE FUNCTION public.get_list_path(list_uuid UUID)
RETURNS TEXT[] AS $$
WITH RECURSIVE path AS (
  -- Base case: start with the target list
  SELECT id, title, parent_id, ARRAY[title] as path, 1 as level
  FROM public.lists 
  WHERE id = list_uuid
  
  UNION ALL
  
  -- Recursive case: add parent to path
  SELECT l.id, l.title, l.parent_id, l.title || p.path, p.level + 1
  FROM public.lists l 
  JOIN path p ON l.id = p.parent_id
  WHERE p.level < 50 -- Prevent infinite recursion
)
SELECT path 
FROM path 
WHERE parent_id IS NULL
ORDER BY level DESC
LIMIT 1;
$$ LANGUAGE SQL STABLE;

-- Function to get all descendants of a list
CREATE OR REPLACE FUNCTION public.get_list_descendants(list_uuid UUID)
RETURNS TABLE(id UUID, title TEXT, level INTEGER) AS $$
WITH RECURSIVE descendants AS (
  -- Base case: start with the target list
  SELECT l.id, l.title, l.parent_id, 0 as level
  FROM public.lists l
  WHERE l.id = list_uuid
  
  UNION ALL
  
  -- Recursive case: find children
  SELECT l.id, l.title, l.parent_id, d.level + 1
  FROM public.lists l
  JOIN descendants d ON l.parent_id = d.id
  WHERE d.level < 50 -- Prevent infinite recursion
)
SELECT descendants.id, descendants.title, descendants.level
FROM descendants
WHERE descendants.level > 0 -- Exclude the root list itself
ORDER BY descendants.level, descendants.title;
$$ LANGUAGE SQL STABLE;

-- Function to get all ancestors of a list
CREATE OR REPLACE FUNCTION public.get_list_ancestors(list_uuid UUID)
RETURNS TABLE(id UUID, title TEXT, level INTEGER) AS $$
WITH RECURSIVE ancestors AS (
  -- Base case: start with the target list
  SELECT l.id, l.title, l.parent_id, 0 as level
  FROM public.lists l
  WHERE l.id = list_uuid
  
  UNION ALL
  
  -- Recursive case: find parents
  SELECT l.id, l.title, l.parent_id, a.level + 1
  FROM public.lists l
  JOIN ancestors a ON l.id = a.parent_id
  WHERE a.level < 50 -- Prevent infinite recursion
)
SELECT ancestors.id, ancestors.title, ancestors.level
FROM ancestors
WHERE ancestors.level > 0 -- Exclude the target list itself
ORDER BY ancestors.level DESC;
$$ LANGUAGE SQL STABLE;