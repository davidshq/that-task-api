# Technology Stack

## Project Status
Early stage - architecture and design phase. No implementation code exists yet.

## Core Platform
**Supabase** - Backend-as-a-Service providing:
- Managed PostgreSQL database
- Auto-generated REST APIs (PostgREST)
- Built-in authentication and authorization
- Real-time subscriptions
- Edge Functions (Deno runtime)
- Row Level Security (RLS)

## Architecture Approach
- **Database-first design** with schema-driven API generation
- **Real-time capabilities** for live task updates
- **Edge Functions** for custom business logic
- **PostgreSQL features** for hierarchical data and complex queries

## Core Data Models
- **Users**: Built-in Supabase Auth with custom profiles
- **Lists**: Hierarchical organization using recursive relationships
- **Tasks**: Core entity with JSONB for flexible metadata
- **Custom Fields**: JSONB columns with database validation

## Key Technical Implementation
- **Polymorphic node tree**: PostgreSQL recursive CTEs for hierarchy
- **Audit logging**: Database triggers for automatic change tracking
- **Notifications**: Edge Functions + database triggers
- **Recurring tasks**: Edge Functions with cron scheduling
- **Permissions**: Row Level Security policies for fine-grained access

## Development Tools
- **Supabase CLI**: Database migrations and local development
- **@supabase/supabase-js**: Client library for API access
- **SQL migrations**: Version-controlled schema changes
- **Edge Functions**: TypeScript/Deno for custom logic

## Integration Patterns
- **External sync**: Edge Functions for TaskWarrior-style integrations
- **Non-member notifications**: Custom Edge Functions with external APIs
- **Multi-UI support**: Auto-generated APIs accessible from any client

## Development Commands
```bash
# Local development
supabase start
supabase db reset
supabase functions serve

# Migrations
supabase db diff -f migration_name
supabase db push

# Edge Functions
supabase functions new function_name
supabase functions deploy function_name
```

## Key Dependencies
- `@supabase/supabase-js` - Client library
- `supabase` - CLI tool
- PostgreSQL extensions (pg_cron, uuid-ossp, etc.)

## Architecture Benefits
- Rapid API development with auto-generation
- Built-in real-time capabilities
- Excellent PostgreSQL support for hierarchical data
- Integrated authentication and authorization
- Simplified deployment and scaling