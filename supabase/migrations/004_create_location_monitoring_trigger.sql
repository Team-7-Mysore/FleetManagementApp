-- Migration: Create database trigger for location monitoring
-- Task: 3.1, 3.2
-- Requirements: 6.1, 6.4, 7.1, 7.4
-- Description: Sets up PostgreSQL trigger to automatically invoke monitor-geofences Edge Function
--              when vehicle locations are updated

-- ============================================================================
-- Configuration Instructions
-- ============================================================================
-- Before this trigger can invoke the Edge Function, you must configure the
-- Supabase URL and service role key using the following SQL commands:
--
-- ALTER DATABASE postgres SET app.settings.supabase_url = 'https://[project-ref].supabase.co';
-- ALTER DATABASE postgres SET app.settings.service_role_key = '[service-role-key]';
--
-- Replace [project-ref] with your Supabase project reference ID
-- Replace [service-role-key] with your Supabase service role key
--
-- These settings are stored at the database level and persist across sessions.
-- ============================================================================

-- ============================================================================
-- Enable pg_net extension for HTTP requests
-- ============================================================================
-- The pg_net extension is required for net.http_post function
-- This extension is typically pre-installed in Supabase, but we ensure it's enabled
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ============================================================================
-- Task 3.1: Create trigger function to invoke monitor-geofences
-- ============================================================================

CREATE OR REPLACE FUNCTION trigger_monitor_geofences()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    supabase_url TEXT;
    service_role_key TEXT;
BEGIN
    -- Get Supabase URL and service role key from environment
    -- These should be set using: ALTER DATABASE postgres SET app.settings.supabase_url = 'https://[project-ref].supabase.co';
    -- and: ALTER DATABASE postgres SET app.settings.service_role_key = '[service-role-key]';
    supabase_url := current_setting('app.settings.supabase_url', true);
    service_role_key := current_setting('app.settings.service_role_key', true);
    
    -- If settings are not configured, log error and return
    -- This prevents the trigger from failing during development/testing
    IF supabase_url IS NULL OR service_role_key IS NULL THEN
        RAISE WARNING 'Supabase URL or service role key not configured. Skipping geofence monitoring.';
        RETURN NEW;
    END IF;
    
    -- Invoke Edge Function asynchronously using net.http_post
    -- This function is called after each INSERT or UPDATE on vehicle_locations
    PERFORM net.http_post(
        url := supabase_url || '/functions/v1/monitor-geofences',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || service_role_key
        ),
        body := jsonb_build_object(
            'vehicle_id', NEW.vehicle_id,
            'latitude', NEW.latitude,
            'longitude', NEW.longitude,
            'timestamp', NEW.timestamp
        )
    );
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't fail the location update
        RAISE WARNING 'Failed to invoke monitor-geofences Edge Function: %', SQLERRM;
        RETURN NEW;
END;
$$;

-- ============================================================================
-- Task 3.2: Create trigger on vehicle_locations table
-- ============================================================================

-- Note: This trigger assumes the vehicle_locations table exists
-- The table should have columns: vehicle_id, latitude, longitude, timestamp
-- If the table doesn't exist yet, this trigger creation will fail

CREATE TRIGGER on_vehicle_location_update
AFTER INSERT OR UPDATE ON vehicle_locations
FOR EACH ROW
EXECUTE FUNCTION trigger_monitor_geofences();

-- ============================================================================
-- Comments and Documentation
-- ============================================================================

COMMENT ON FUNCTION trigger_monitor_geofences() IS 
'Trigger function that invokes the monitor-geofences Edge Function asynchronously when vehicle locations are updated. 
Passes vehicle_id, latitude, longitude, and timestamp to the Edge Function for geofence monitoring.
Requirements: 6.1 (entry detection), 7.1 (exit detection)';

COMMENT ON TRIGGER on_vehicle_location_update ON vehicle_locations IS
'Automatically invokes geofence monitoring when vehicle locations are inserted or updated.
Ensures entry and exit events are detected within 30 seconds (Requirements 6.4, 7.4).';
