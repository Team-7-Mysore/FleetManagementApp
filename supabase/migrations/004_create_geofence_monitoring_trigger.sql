-- Migration: Create database trigger for geofence monitoring
-- This trigger automatically invokes the monitor-geofences Edge Function
-- whenever a vehicle location is inserted or updated

-- Enable the http extension if not already enabled (required for net.http_post)
CREATE EXTENSION IF NOT EXISTS http;

-- Create the trigger function that invokes the monitor-geofences Edge Function
CREATE OR REPLACE FUNCTION trigger_monitor_geofences()
RETURNS TRIGGER AS $$
DECLARE
    project_url TEXT;
    service_role_key TEXT;
BEGIN
    -- Get the Supabase project URL from environment or use placeholder
    -- Replace 'YOUR_PROJECT_REF' with your actual Supabase project reference
    project_url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/monitor-geofences';
    
    -- Note: In production, use a secure method to store and retrieve the service role key
    -- For now, this is a placeholder that you'll need to configure
    service_role_key := current_setting('app.settings.service_role_key', true);
    
    -- Invoke the Edge Function asynchronously using net.http_post
    PERFORM net.http_post(
        url := project_url,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || COALESCE(service_role_key, '')
        ),
        body := jsonb_build_object(
            'vehicle_id', NEW.vehicle_id,
            'latitude', NEW.latitude,
            'longitude', NEW.longitude,
            'timestamp', NEW.timestamp
        )
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger on vehicle_locations table
-- This trigger fires AFTER INSERT OR UPDATE for each row
CREATE TRIGGER on_vehicle_location_update
AFTER INSERT OR UPDATE ON vehicle_locations
FOR EACH ROW
EXECUTE FUNCTION trigger_monitor_geofences();

-- Add comment for documentation
COMMENT ON FUNCTION trigger_monitor_geofences() IS 
'Trigger function that invokes the monitor-geofences Edge Function when vehicle locations are updated';

COMMENT ON TRIGGER on_vehicle_location_update ON vehicle_locations IS 
'Automatically monitors geofence entry/exit events when vehicle locations change';
