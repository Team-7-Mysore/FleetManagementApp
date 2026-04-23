-- Migration: Enable RLS and create policies for geofence tables
-- Requirements: 16.1, 16.2, 16.3, 16.4, 16.5

-- Helper: returns true if the calling user has the fleet_manager role
CREATE OR REPLACE FUNCTION is_fleet_manager()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM users
    WHERE user_id = auth.uid()
      AND role = 'fleet_manager'
  );
$$;

-- ============================================================
-- geofences
-- ============================================================

ALTER TABLE geofences ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read geofences
CREATE POLICY "geofences_select"
  ON geofences FOR SELECT
  TO authenticated
  USING (true);

-- Only fleet managers can insert
CREATE POLICY "geofences_insert"
  ON geofences FOR INSERT
  TO authenticated
  WITH CHECK (is_fleet_manager());

-- Only fleet managers can update
CREATE POLICY "geofences_update"
  ON geofences FOR UPDATE
  TO authenticated
  USING (is_fleet_manager())
  WITH CHECK (is_fleet_manager());

-- Only fleet managers can delete
CREATE POLICY "geofences_delete"
  ON geofences FOR DELETE
  TO authenticated
  USING (is_fleet_manager());

-- ============================================================
-- geofence_assignments
-- ============================================================

ALTER TABLE geofence_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "geofence_assignments_select"
  ON geofence_assignments FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "geofence_assignments_insert"
  ON geofence_assignments FOR INSERT
  TO authenticated
  WITH CHECK (is_fleet_manager());

CREATE POLICY "geofence_assignments_delete"
  ON geofence_assignments FOR DELETE
  TO authenticated
  USING (is_fleet_manager());

-- ============================================================
-- geofence_events
-- ============================================================

ALTER TABLE geofence_events ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read events
CREATE POLICY "geofence_events_select"
  ON geofence_events FOR SELECT
  TO authenticated
  USING (true);

-- Edge Functions (service_role) insert events — no authenticated INSERT policy needed.
-- If you need authenticated inserts too, add one here.
