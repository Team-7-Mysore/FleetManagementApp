# SDV Integration & Fleet Management Implementation Plan

This document outlines the step-by-step implementation plan for integrating the Software-Defined Vehicle (SDV) simulator telemetry, automated inspections, fuel invoice scanning, and reporting into the Fleet Management System (iOS + Supabase).

## Phase 1: Database Schema & Backend Updates
**Goal:** Prepare Supabase to handle the new data models efficiently without bloat.

- [ ] **1.1. Create Fuel Logs Table & Storage**
  - Create `public.fuel_logs` table to store fuel volume, cost, odometer, and receipt URL.
  - Create a public Supabase Storage Bucket named `fuel-receipts`.
- [ ] **1.2. Create Inspection Items Table**
  - Create `public.inspection_items` (child of `inspections`) with fields: `category`, `name`, `status` (`pending`, `pass`, `fail`), and `notes`.
- [ ] **1.3. Modify Existing Tables**
  - Add cache columns to `vehicles`: `current_odometer`, `current_fuel_level`.
  - Add snapshot columns to `trips`: `start_odometer`, `end_odometer`, `start_fuel_level`, `end_fuel_level`.
- [ ] **1.4. Create Alerts & Triggers**
  - Create `public.vehicle_faults` table for simulator events (crashes, component failures).
  - Create a Postgres Trigger on `vehicle_faults` to automatically insert a notification into `public.notifications` for critical alerts.
- [ ] **1.5. Create Reporting RPC**
  - Create the `get_vehicle_report(vehicle_id, start_date, end_date)` Postgres function to aggregate trips, distance, fuel costs, and issues for the Fleet Manager.

## Phase 2: SDV Simulator Updates (React App)
**Goal:** Adjust the simulator to use the "Lean Telemetry Strategy" so it doesn't bloat the database.

- [ ] **2.1. Live Telemetry Broadcast**
  - Modify `telematicsService.js` to broadcast high-frequency telemetry (1s-5s) to Supabase Realtime Channels (Broadcast) instead of inserting rows.
- [ ] **2.2. Trip Snapshot Logic**
  - Make the simulator update the `trips` table directly ONLY at the start of a trip (logging start fuel/odometer) and at the end of a trip.
- [ ] **2.3. Fault Event Triggers**
  - Modify the `faultPanel.jsx` / fault injection logic to perform an `INSERT` into the new `vehicle_faults` table when a fault is simulated.

## Phase 3: iOS App - Driver Experience
**Goal:** Implement SDV auto-inspections and fuel receipt scanning.

- [ ] **3.1. Auto/Manual Inspection Logic**
  - In the Pre-Trip/Post-Trip view, fetch the active vehicle's `is_sdvs_enabled` flag.
  - **Manual Fallback:** Present the standard checklist UI for manual Pass/Fail toggles.
  - **SDV Auto-pass:** Present an automated scanning UI. Use SwiftUI animations (e.g., repeating a scanline over a car wireframe) and a Timer to automatically mark `InspectionItem`s as `pass` sequentially.
  - Batch insert the `inspections` and `inspection_items` to Supabase upon completion.
- [ ] **3.2. Fuel Invoice Scanner**
  - Create `LogFuelView.swift`.
  - Integrate Apple's `VNDocumentCameraViewController` for receipt scanning and auto-cropping.
  - Optional: Use `VNRecognizeTextRequest` (VisionKit) to extract total cost and fuel volume.
  - Upload the cropped image to the `fuel-receipts` bucket and insert the record into `fuel_logs`.

## Phase 4: iOS App - Fleet Manager Experience
**Goal:** Provide live monitoring, vehicle reports, and fuel tracking.

- [ ] **4.1. Live Map Tracking**
  - Update `VehicleMapView.swift` to subscribe to the Supabase Realtime Broadcast channel for the selected vehicle.
  - Animate the vehicle pin based on the ephemeral coordinate stream (bypassing the database).
- [ ] **4.2. Fuel Logs Dashboard**
  - Create `VehicleFuelLogsView.swift` inside the Vehicle Details tab.
  - Fetch and display the list of `fuel_logs`. Include an image viewer to tap and inspect the uploaded receipt.
- [ ] **4.3. Downloadable Vehicle Reports**
  - Create `VehicleReportGeneratorView.swift` allowing date-range selection.
  - Query the `get_vehicle_report` RPC via the Supabase Swift client.
  - Build a declarative SwiftUI report layout displaying aggregated distance, costs, and a list of issues.
  - Implement PDF export using `ImageRenderer(content: ReportView())` to allow the manager to share the report natively.
