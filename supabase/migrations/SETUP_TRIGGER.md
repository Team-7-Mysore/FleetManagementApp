# Setup Guide: Database Trigger for Geofence Monitoring

This guide explains how to set up and configure the database trigger for automatic geofence monitoring.

## Prerequisites

1. Supabase project created and configured
2. Edge Functions deployed (`monitor-geofences` and `send-geofence-notification`)
3. Database migrations 001-003 applied (geofences, assignments, events tables)
4. `vehicle_locations` table exists in your database

## Step 1: Apply the Migration

Apply migration 004 to create the trigger function and trigger:

```bash
# Using Supabase CLI
supabase db push

# Or apply specific migration
supabase db push --file supabase/migrations/004_create_location_monitoring_trigger.sql
```

This will:
- Enable the `pg_net` extension (if not already enabled)
- Create the `trigger_monitor_geofences()` function
- Create the `on_vehicle_location_update` trigger on the `vehicle_locations` table

## Step 2: Configure Database Settings

The trigger requires two configuration settings to invoke the Edge Function. You need to set these in your Supabase database.

### Find Your Configuration Values

1. **Supabase URL**:
   - Go to Supabase Dashboard > Settings > General
   - Copy the "Reference ID" (e.g., `abcdefghijklmnop`)
   - Your URL is: `https://[reference-id].supabase.co`

2. **Service Role Key**:
   - Go to Supabase Dashboard > Settings > API
   - Copy the `service_role` key (under "Project API keys")
   - ⚠️ **Important**: This is a secret key - keep it secure!

### Set the Configuration

Connect to your Supabase database and run these SQL commands:

```sql
-- Set Supabase URL (replace with your actual project reference)
ALTER DATABASE postgres SET app.settings.supabase_url = 'https://your-project-ref.supabase.co';

-- Set service role key (replace with your actual service role key)
ALTER DATABASE postgres SET app.settings.service_role_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

**Using Supabase SQL Editor**:
1. Go to Supabase Dashboard > SQL Editor
2. Create a new query
3. Paste the ALTER DATABASE commands with your actual values
4. Run the query

**Using psql**:
```bash
psql "postgresql://postgres:[password]@db.[project-ref].supabase.co:5432/postgres" \
  -c "ALTER DATABASE postgres SET app.settings.supabase_url = 'https://your-project-ref.supabase.co';" \
  -c "ALTER DATABASE postgres SET app.settings.service_role_key = 'your-service-role-key';"
```

### Verify Configuration

Check that the settings were applied:

```sql
SELECT name, setting 
FROM pg_settings 
WHERE name LIKE 'app.settings%';
```

You should see:
```
              name               |                    setting                    
---------------------------------+-----------------------------------------------
 app.settings.service_role_key   | eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
 app.settings.supabase_url       | https://your-project-ref.supabase.co
```

## Step 3: Test the Trigger

### Test 1: Insert a Vehicle Location

```sql
-- Insert a test location (replace with actual vehicle_id)
INSERT INTO vehicle_locations (vehicle_id, latitude, longitude, timestamp)
VALUES (
    'your-vehicle-uuid',
    37.7749,  -- San Francisco latitude
    -122.4194, -- San Francisco longitude
    NOW()
);
```

### Test 2: Check Edge Function Logs

1. Go to Supabase Dashboard > Edge Functions
2. Click on `monitor-geofences`
3. Go to the "Logs" tab
4. You should see a log entry showing the function was invoked with your test data

### Test 3: Check for Geofence Events

If the vehicle entered or exited any assigned geofences, you should see events:

```sql
SELECT 
    e.event_type,
    e.timestamp,
    g.name AS geofence_name,
    e.latitude,
    e.longitude
FROM geofence_events e
JOIN geofences g ON e.geofence_id = g.geofence_id
WHERE e.vehicle_id = 'your-vehicle-uuid'
ORDER BY e.timestamp DESC
LIMIT 10;
```

## Troubleshooting

### Issue: Trigger Not Firing

**Check if trigger exists:**
```sql
SELECT tgname, tgenabled, tgrelid::regclass 
FROM pg_trigger 
WHERE tgname = 'on_vehicle_location_update';
```

**Check if trigger is enabled:**
```sql
-- tgenabled should be 'O' (origin/enabled)
SELECT tgname, tgenabled FROM pg_trigger WHERE tgname = 'on_vehicle_location_update';
```

**Enable trigger if disabled:**
```sql
ALTER TABLE vehicle_locations ENABLE TRIGGER on_vehicle_location_update;
```

### Issue: Configuration Warnings

If you see warnings like "Supabase URL or service role key not configured":

1. Verify settings are set (see "Verify Configuration" above)
2. Reconnect to the database to load new settings
3. Check for typos in the setting names

### Issue: Edge Function Not Invoked

**Check pg_net extension:**
```sql
SELECT * FROM pg_extension WHERE extname = 'pg_net';
```

If not found:
```sql
CREATE EXTENSION pg_net;
```

**Check Edge Function is deployed:**
```bash
supabase functions list
```

You should see `monitor-geofences` in the list.

**Test Edge Function manually:**
```bash
curl -X POST https://your-project-ref.supabase.co/functions/v1/monitor-geofences \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-service-role-key" \
  -d '{
    "vehicle_id": "test-uuid",
    "latitude": 37.7749,
    "longitude": -122.4194,
    "timestamp": "2024-01-15T10:00:00Z"
  }'
```

### Issue: Permission Errors

If you see permission errors in the logs:

1. Verify the service role key is correct
2. Ensure the Edge Function has proper permissions
3. Check Row Level Security (RLS) policies on related tables

## Performance Monitoring

Monitor trigger performance:

```sql
-- Check recent trigger executions (if logging is enabled)
SELECT * FROM pg_stat_user_functions 
WHERE funcname = 'trigger_monitor_geofences';
```

Monitor Edge Function performance:
- Supabase Dashboard > Edge Functions > monitor-geofences > Metrics
- Check execution time, error rate, and invocation count

## Security Considerations

1. **Service Role Key**: The service role key bypasses Row Level Security (RLS). It's stored at the database level and not exposed to clients.

2. **Database Settings**: The settings are stored in the database and accessible to database users with appropriate permissions.

3. **HTTPS Only**: The trigger only invokes HTTPS endpoints for security.

4. **Error Handling**: The trigger catches exceptions and logs warnings without failing location updates, preventing denial of service.

## Disabling the Trigger

If you need to temporarily disable the trigger:

```sql
-- Disable trigger
ALTER TABLE vehicle_locations DISABLE TRIGGER on_vehicle_location_update;

-- Re-enable trigger
ALTER TABLE vehicle_locations ENABLE TRIGGER on_vehicle_location_update;
```

## Removing the Trigger

To completely remove the trigger and function:

```sql
-- Drop trigger
DROP TRIGGER IF EXISTS on_vehicle_location_update ON vehicle_locations;

-- Drop function
DROP FUNCTION IF EXISTS trigger_monitor_geofences();
```

## Next Steps

After setting up the trigger:

1. **Test with Real Data**: Insert actual vehicle locations and verify geofence events are created
2. **Monitor Performance**: Check Edge Function execution times and error rates
3. **Set Up Alerts**: Configure monitoring alerts for trigger failures
4. **Proceed to Task 4**: Test backend monitoring with sample data

## Support

For issues or questions:
- Check Supabase Dashboard > Edge Functions > Logs for detailed error messages
- Review PostgreSQL logs for trigger warnings
- Consult the design document: `.kiro/specs/geofencing-management/design.md`
- Review task summary: `supabase/migrations/TASK_3_SUMMARY.md`
