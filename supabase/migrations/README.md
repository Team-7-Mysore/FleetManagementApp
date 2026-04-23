# Database Migrations

This folder contains SQL migration files for the Fleet Management System database.

## Applying Migrations

### Option 1: Using Supabase CLI (Recommended)

If you have the Supabase CLI installed:

```bash
# Apply all pending migrations
supabase db push

# Or apply a specific migration
supabase db execute --file supabase/migrations/001_create_geofences_table.sql
```

### Option 2: Using Supabase Dashboard

1. Go to your Supabase project dashboard
2. Navigate to the SQL Editor
3. Copy the contents of the migration file
4. Paste and execute the SQL

### Option 3: Using Supabase API

You can also execute the SQL using the Supabase client in your application code (for development/testing only).

## Migration Files

- `001_create_geofences_table.sql` - Creates the geofences table with validation constraints and indexes
- `002_create_geofence_assignments_table.sql` - Creates the geofence_assignments table for vehicle-geofence relationships
- `003_create_geofence_events_table.sql` - Creates the geofence_events table for storing entry/exit events with dwell time tracking

## Migration Naming Convention

Migrations are named with the following pattern:
```
{number}_{description}.sql
```

Where:
- `{number}` is a sequential number (001, 002, etc.)
- `{description}` is a brief description of the migration using snake_case

## Notes

- Always test migrations in a development environment first
- Migrations should be idempotent (safe to run multiple times)
- Use `IF NOT EXISTS` clauses where appropriate
- Document which requirements each migration satisfies
