# Geofences Table Quick Start Guide

## Apply the Migration

### Using Supabase Dashboard (Easiest)

1. Open your Supabase project: https://qisdvwaldlghndrudbvr.supabase.co
2. Go to **SQL Editor** in the left sidebar
3. Click **New Query**
4. Copy the contents of `supabase/migrations/001_create_geofences_table.sql`
5. Paste into the SQL editor
6. Click **Run** or press `Cmd/Ctrl + Enter`
7. Verify success message appears

### Using Supabase CLI

```bash
# If you have Supabase CLI installed
supabase db push

# Or execute specific file
supabase db execute --file supabase/migrations/001_create_geofences_table.sql
```

## Verify the Migration

Run the verification script to confirm the table was created correctly:

1. Open SQL Editor in Supabase Dashboard
2. Copy contents of `supabase/migrations/verify/001_verify_geofences_table.sql`
3. Run the query
4. Check that:
   - `table_exists` returns `TRUE`
   - 8 columns are present
   - 4 CHECK constraints exist
   - 2 indexes exist

## Test the Constraints

To test that the constraints work correctly, you can run the test file:

```sql
-- Copy and run: supabase/migrations/tests/001_test_geofences_table.sql
```

This will:
- Insert valid test data
- Verify boundary values work
- Confirm all three geofence types are accepted
- Check indexes exist
- Clean up test data

## Quick Test

Run this quick test to verify everything works:

```sql
-- Insert a test geofence
INSERT INTO geofences (name, latitude, longitude, radius, type)
VALUES ('Test Depot', 37.7749, -122.4194, 100, 'depot')
RETURNING *;

-- Verify it was created
SELECT * FROM geofences WHERE name = 'Test Depot';

-- Clean up
DELETE FROM geofences WHERE name = 'Test Depot';
```

## Common Issues

### Issue: Table already exists
**Solution**: The migration uses `IF NOT EXISTS`, so it's safe to run multiple times.

### Issue: Permission denied
**Solution**: Ensure you're logged in as a user with database creation permissions.

### Issue: Constraint violation when inserting data
**Solution**: Check that your data meets these requirements:
- Latitude: -90 to 90
- Longitude: -180 to 180
- Radius: 50 to 10,000 meters
- Type: 'depot', 'delivery', or 'restricted'

## Next Steps

After applying this migration:

1. ✅ Geofences table is ready
2. ⏭️ Apply migration 002 for geofence_assignments table (coming next)
3. ⏭️ Apply migration 003 for geofence_events table (coming next)
4. ⏭️ Set up Edge Functions for monitoring (coming next)

## Swift Integration

Once the table is created, you can use it in your Swift code:

```swift
// Example: Fetch all geofences
let geofences: [Geofence] = try await supabase
    .from("geofences")
    .select()
    .execute()
    .value

// Example: Create a geofence
let newGeofence = GeofenceInsert(
    name: "Main Depot",
    latitude: 37.7749,
    longitude: -122.4194,
    radius: 500,
    type: "depot"
)

try await supabase
    .from("geofences")
    .insert(newGeofence)
    .execute()
```

## Support

If you encounter issues:
1. Check the verification script output
2. Review the SCHEMA.md for detailed table structure
3. Run the test script to identify specific constraint issues
4. Check Supabase logs in the Dashboard
