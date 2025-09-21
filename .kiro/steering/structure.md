# Project Structure

## Repository Organization

### Documentation (`docs/`)
- **`docs/architecture/`**: Core system design documents
  - `basic-functionality.md`: Core entities and data models
  - `sync-functionality.md`: External synchronization patterns
  - `ui.md`: UI considerations and integration patterns
  - `unique-functionality.md`: Distinctive features (gamification, non-member interactions)
  - `other-functionality.md`: Integration examples and external tools
  - `data-models/organizational.md`: Hierarchical data model design
- **`docs/research/`**: Market research and competitive analysis
  - `important-resources.md`: Key references and specifications
  - `popular-solutions.md`: Existing solutions analysis

### Configuration
- **`.vscode/`**: VS Code workspace settings
- **`.kiro/`**: Kiro AI assistant configuration and steering rules

## Design Principles

### Documentation-First Approach
- Comprehensive architecture documentation before implementation
- Research-driven design decisions
- Clear separation of concerns in documentation structure

### Hierarchical Organization
- Everything-as-a-list model for organizational flexibility
- Polymorphic node tree structure
- Support for deep nesting: Company → Department → Project → Group → Task

### Extensibility Focus
- Custom fields system
- Plugin-friendly architecture
- Multiple UI paradigm support

## File Naming Conventions
- Kebab-case for documentation files
- Descriptive, purpose-driven naming
- Logical grouping by functionality and concern