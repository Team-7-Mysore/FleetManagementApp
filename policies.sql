CREATE POLICY "Users can view own data" ON public.users FOR SELECT TO public USING ((auth.uid() = user_id));
CREATE POLICY "Allow insert for all" ON public.trips FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow select for all" ON public.trips FOR SELECT TO public USING (true);
CREATE POLICY "Allow read access" ON public.inventory FOR SELECT TO public USING (true);
CREATE POLICY "Allow public read" ON public.inventory FOR SELECT TO public USING (true);
CREATE POLICY "Allow public read access" ON public.work_order_tasks FOR SELECT TO public USING (true);
CREATE POLICY "Allow public insert access" ON public.work_order_tasks FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow public update access" ON public.work_order_tasks FOR UPDATE TO public USING (true);
CREATE POLICY "Allow public delete access" ON public.work_order_tasks FOR DELETE TO public USING (true);
CREATE POLICY "Allow public read access on work_order_tasks" ON public.work_order_tasks FOR SELECT TO public USING (true);
CREATE POLICY "Allow public insert access on work_order_tasks" ON public.work_order_tasks FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow public update access on work_order_tasks" ON public.work_order_tasks FOR UPDATE TO public USING (true);
CREATE POLICY "Allow public delete access on work_order_tasks" ON public.work_order_tasks FOR DELETE TO public USING (true);
CREATE POLICY "Allow public read access on work_order_parts" ON public.work_order_parts FOR SELECT TO public USING (true);
CREATE POLICY "Allow public insert access on work_order_parts" ON public.work_order_parts FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow public update access on work_order_parts" ON public.work_order_parts FOR UPDATE TO public USING (true);
CREATE POLICY "Allow public delete access on work_order_parts" ON public.work_order_parts FOR DELETE TO public USING (true);
CREATE POLICY "Allow insert for all users" ON public.inventory FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow update for all users" ON public.inventory FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "read messages" ON public.chat_messages FOR SELECT TO public USING (true);
CREATE POLICY "send messages" ON public.chat_messages FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "update messages" ON public.chat_messages FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "vehicles_select_for_app" ON public.vehicles FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "drivers_select_for_app" ON public.drivers FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "users_select_for_app" ON public.users FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "trips_select_for_app" ON public.trips FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow read vehicle documents" ON public.vehicle_documents FOR SELECT TO anon USING (true);
CREATE POLICY "Allow insert vehicle documents" ON public.vehicle_documents FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow update vehicle documents" ON public.vehicle_documents FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow delete vehicle documents" ON public.vehicle_documents FOR DELETE TO anon USING (true);
CREATE POLICY "Allow inserts for all" ON public.work_order_tasks FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow inserts for all" ON public.work_order_parts FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow delete for all users" ON public.inventory FOR DELETE TO public USING (true);
CREATE POLICY "Enable insert for authenticated users only" ON public.drivers FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Enable read access for all users" ON public.drivers FOR SELECT TO public USING (true);
CREATE POLICY "Enable update for all users" ON public.drivers FOR UPDATE TO public USING (true);
CREATE POLICY "Enable delete for all users" ON public.drivers FOR DELETE TO public USING (true);
CREATE POLICY "Allow insert for authenticated users" ON public.users FOR INSERT TO authenticated WITH CHECK ((auth.uid() = created_by));
CREATE POLICY "fleet_manager_can_insert_users" ON public.users FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "Users can delete own notifications" ON public.notifications FOR DELETE TO authenticated USING ((auth.uid() = recipient_id));
CREATE POLICY "Managers can update any user" ON public.users FOR UPDATE TO public USING ((EXISTS ( SELECT 1
   FROM users manager_record
  WHERE ((manager_record.user_id = auth.uid()) AND (manager_record.role = 'fleet_manager'::user_role)))));
CREATE POLICY "Drivers can insert their own reports" ON public.driver_reports FOR INSERT TO authenticated WITH CHECK ((driver_id IN ( SELECT drivers.driver_id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))));
CREATE POLICY "Allow public inserts to reports table" ON public.work_order_reports FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow public select on reports table" ON public.work_order_reports FOR SELECT TO public USING (true);
CREATE POLICY "Allow updates for authenticated users" ON public.vehicles FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow select for authenticated users" ON public.vehicles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow public inserts" ON public.notifications FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Users can read own notifications" ON public.notifications FOR SELECT TO public USING (true);
CREATE POLICY "geofences_select" ON public.geofences FOR SELECT TO authenticated USING (true);
CREATE POLICY "geofences_insert" ON public.geofences FOR INSERT TO authenticated WITH CHECK (is_fleet_manager());
CREATE POLICY "geofences_update" ON public.geofences FOR UPDATE TO authenticated USING (is_fleet_manager()) WITH CHECK (is_fleet_manager());
CREATE POLICY "geofences_delete" ON public.geofences FOR DELETE TO authenticated USING (is_fleet_manager());
CREATE POLICY "geofence_assignments_select" ON public.geofence_assignments FOR SELECT TO authenticated USING (true);
CREATE POLICY "geofence_assignments_insert" ON public.geofence_assignments FOR INSERT TO authenticated WITH CHECK (is_fleet_manager());
CREATE POLICY "geofence_assignments_delete" ON public.geofence_assignments FOR DELETE TO authenticated USING (is_fleet_manager());
CREATE POLICY "geofence_events_select" ON public.geofence_events FOR SELECT TO authenticated USING (true);
CREATE POLICY "User can update own status" ON public.users FOR UPDATE TO public USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "Allow public read access on work_order" ON public.work_order_tasks FOR SELECT TO public USING (true);
CREATE POLICY "Allow public insert access on work_orders" ON public.work_order_tasks FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow public update access on work_orders" ON public.work_order_tasks FOR UPDATE TO public USING (true);
CREATE POLICY "Allow public delete access on work_orders" ON public.work_order_tasks FOR DELETE TO public USING (true);
CREATE POLICY "Full Access Policy" ON public.work_orders FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "trips_update_for_driver" ON public.trips FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM drivers d
  WHERE ((d.driver_id = trips.driver_id) AND (d.user_id = auth.uid()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM drivers d
  WHERE ((d.driver_id = trips.driver_id) AND (d.user_id = auth.uid())))));
CREATE POLICY "chat_rooms_select_all" ON public.chat_rooms FOR SELECT TO public USING (true);
CREATE POLICY "chat_rooms_insert_all" ON public.chat_rooms FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "chat_rooms_update_all" ON public.chat_rooms FOR UPDATE TO public USING (true);
CREATE POLICY "chat_rooms_delete_all" ON public.chat_rooms FOR DELETE TO public USING (true);
CREATE POLICY "chat_participants_select_all" ON public.chat_participants FOR SELECT TO public USING (true);
CREATE POLICY "chat_participants_insert_all" ON public.chat_participants FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "chat_participants_update_all" ON public.chat_participants FOR UPDATE TO public USING (true);
CREATE POLICY "chat_participants_delete_all" ON public.chat_participants FOR DELETE TO public USING (true);
CREATE POLICY "Public read maintenance issues" ON public.maintenance_issues FOR SELECT TO public USING (true);
CREATE POLICY "Public insert maintenance issues" ON public.maintenance_issues FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public update maintenance issues" ON public.maintenance_issues FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Public delete maintenance issues" ON public.maintenance_issues FOR DELETE TO public USING (true);
CREATE POLICY "routes: authenticated select" ON public.routes FOR SELECT TO authenticated USING (true);
CREATE POLICY "routes: authenticated insert" ON public.routes FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "routes: authenticated update" ON public.routes FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow public insert" ON public.vehicle_locations FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow public update" ON public.vehicle_locations FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "simulator_insert_vehicle_locations" ON public.vehicle_locations FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "simulator_select_vehicle_locations" ON public.vehicle_locations FOR SELECT TO anon USING (true);
CREATE POLICY "simulator_update_trips" ON public.trips FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "simulator_insert_driver_reports" ON public.driver_reports FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "simulator_update_vehicle_locations" ON public.vehicle_locations FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "allow_select_routes" ON public.routes FOR SELECT TO anon USING (true);
CREATE POLICY "vehicle_locations_select_public" ON public.vehicle_locations FOR SELECT TO public USING (true);
CREATE POLICY "Allow public updates" ON public.notifications FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Managers can delete staff" ON public.users FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM users users_1
  WHERE ((users_1.user_id = auth.uid()) AND (users_1.role = 'fleet_manager'::user_role)))));
CREATE POLICY "simulator_insert_fuel_logs" ON public.fuel_logs FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "simulator_insert_telemetry" ON public.vehicle_telemetry_snapshots FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "simulator_update_telemetry" ON public.vehicle_telemetry_snapshots FOR UPDATE TO anon USING (true) WITH CHECK (true);
