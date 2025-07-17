# Is Everything A List?

## Overview
I'm thinking *almost everything* could be a list?

In many apps one has all these different organizational types - e.g. "Company", "Department", "Project", "Group", "List" and these often are nested deeply:

Company -> Department -> Project -> Group -> List

And each of these has different attributes. In this case you could still nest deepily but it would look like this:

Company (Type: List) -> Department (Type: List) -> Project (Type: List) -> Group (Type: List) -> Task (Type: Task)

## Additional Names for "Lists"
- Trello - "Board"
- Asana - "Workspace", "Project", "Section"
- ClickUp - "Workspace", "Space", "Folder"

## ChatGPT Says...
- This is called a "single type" model or a "polymorphic node treet".
- It uses a unified "Node" or "Item" type that supports:
    - Recursive relationships (e.g. each item has `parent_id`)
    - Type tagging or classification (e.g. `type: 'org' | 'project' | 'list' | 'kanoodle'`)
    - Optional metadata extensions per type
- This may be similar to Notion and Roam Research's "blocks", Tana/Workflowy treat everything as a node with metadata.
- Potential downsides include:
    - Validation logic is now application-level
    - UI may need to adopt to different UI types
    - Querying by hierarchy can be complex in SQL
- Potential Enhancements
    - Path caching (store full path as string for fast queries)
    - Type-specific metadata tables (for performance/clarity)
    - Role or permission inheritance
    - Ordering fields