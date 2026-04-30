-- 1. Create fuel_logs table (No redundancy, links directly to trips and vehicles)
CREATE TABLE public.fuel_logs (
    fuel_log_id uuid NOT NULL DEFAULT gen_random_uuid(),
    vehicle_id uuid NOT NULL,
    driver_id uuid,
    trip_id uuid,
    fuel_volume double precision NOT NULL,
    total_cost numeric NOT NULL,
    odometer_reading numeric,
    receipt_image_url text,
    location text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT fuel_logs_pkey PRIMARY KEY (fuel_log_id),
    CONSTRAINT fuel_logs_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(vehicle_id) ON DELETE CASCADE,
    CONSTRAINT fuel_logs_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(driver_id) ON DELETE SET NULL,
    CONSTRAINT fuel_logs_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.trips(trip_id) ON DELETE SET NULL
);

-- 2. Create inspection_items table (Child of existing inspections table)
CREATE TABLE public.inspection_items (
    item_id uuid NOT NULL DEFAULT gen_random_uuid(),
    inspection_id uuid NOT NULL,
    category text NOT NULL CHECK (category IN ('Exterior', 'Mechanical', 'Safety', 'Administrative')),
    name text NOT NULL,
    status text NOT NULL CHECK (status IN ('pending', 'pass', 'fail', 'needs_attention')),
    notes text,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT inspection_items_pkey PRIMARY KEY (item_id),
    CONSTRAINT inspection_items_inspection_id_fkey FOREIGN KEY (inspection_id) REFERENCES public.inspections(id) ON DELETE CASCADE
);

-- 3. Create vehicle_telemetry_snapshots (For live tracking state & caching, reduces continuous writes to vehicles table)
-- Note: 'vehicles' already has 'is_sdvs_enabled'. 
-- Instead of adding current_odometer to vehicles (which causes lock contention), use a 1-to-1 extension table.
CREATE TABLE public.vehicle_telemetry_snapshots (
    vehicle_id uuid NOT NULL PRIMARY KEY,
    current_odometer numeric DEFAULT 0,
    current_fuel_level numeric,
    current_speed double precision,
    last_updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT vehicle_telemetry_snapshots_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(vehicle_id) ON DELETE CASCADE
);

-- 4. Update 'trips' table to track start/end deltas (No time-series bloat)
ALTER TABLE public.trips 
ADD COLUMN start_odometer numeric,
ADD COLUMN end_odometer numeric,
ADD COLUMN start_fuel_level numeric,
ADD COLUMN end_fuel_level numeric;

-- 5. Reports View (Optional RPC to aggregate data for manager reports cleanly)
CREATE OR REPLACE FUNCTION get_vehicle_report(target_vehicle_id UUID, start_date TIMESTAMP, end_date TIMESTAMP)
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'total_trips', (SELECT count(*) FROM trips WHERE vehicle_id = target_vehicle_id AND start_time >= start_date AND end_time <= end_date),
    'distance_travelled', COALESCE((SELECT sum(distance_travelled) FROM trips WHERE vehicle_id = target_vehicle_id AND start_time >= start_date AND end_time <= end_date), 0),
    'fuel_cost', COALESCE((SELECT sum(total_cost) FROM fuel_logs WHERE vehicle_id = target_vehicle_id AND created_at >= start_date AND created_at <= end_date), 0),
    'fuel_volume', COALESCE((SELECT sum(fuel_volume) FROM fuel_logs WHERE vehicle_id = target_vehicle_id AND created_at >= start_date AND created_at <= end_date), 0),
    'reported_issues', (
      SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json)
      FROM driver_reports r 
      WHERE vehicle_id = target_vehicle_id AND created_at >= start_date AND created_at <= end_date
    )
  ) INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 6. Storage Bucket & Policies for 'fuel-receipts'
INSERT INTO storage.buckets (id, name, public) 
VALUES ('fuel-receipts', 'fuel-receipts', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Allow public read access to fuel receipts" 
ON storage.objects FOR SELECT TO public 
USING (bucket_id = 'fuel-receipts');

CREATE POLICY "Allow authenticated users to upload fuel receipts" 
ON storage.objects FOR INSERT TO authenticated 
WITH CHECK (bucket_id = 'fuel-receipts');
