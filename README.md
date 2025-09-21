# That Task API

## Introduction

There are a bazillion task / project management apps out there and I've used a wide variety of them and none does what I want the way I want.

I don't want to add to the mess so I'm focusing on an API/backend first. The goal is to make something that others can use as a solid foundation for their own task / project management apps.

## Development Setup

### Prerequisites
- Node.js (v18 or later)
- Docker (for Supabase local development)

### Getting Started

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Start the local Supabase environment:**
   ```bash
   npm run db:start
   ```

3. **Check status:**
   ```bash
   npm run db:status
   ```

### Local Development URLs
- **API**: http://127.0.0.1:54321
- **Studio**: http://127.0.0.1:54323 (Database management UI)
- **Inbucket**: http://127.0.0.1:54324 (Email testing)

### Useful Commands
- `npm run db:start` - Start local Supabase
- `npm run db:stop` - Stop local Supabase
- `npm run db:reset` - Reset database to initial state
- `npm run db:status` - Check service status

## Architecture

This project uses Supabase as a Backend-as-a-Service with:
- PostgreSQL database with Row Level Security
- Auto-generated REST APIs
- Built-in authentication
- Real-time subscriptions

## Project Structure

- `/docs` - Architecture and design documentation
- `/supabase` - Database migrations, functions, and configuration
- `/.kiro/specs` - Feature specifications and implementation plans