// Supabase Edge Function: monitor-geofences
// Monitors vehicle location updates and detects geofence entry/exit events

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface VehicleLocation {
  vehicle_id: string;
  latitude: number;
  longitude: number;
  timestamp: string;
}

interface Geofence {
  geofence_id: string;
  name: string;
  latitude: number;
  longitude: number;
  radius: number;
  type: "depot" | "delivery" | "restricted";
}

interface GeofenceEvent {
  geofence_id: string;
  vehicle_id: string;
  event_type: "entry" | "exit";
  timestamp: string;
  latitude: number;
  longitude: number;
  dwell_time?: number;
}

/**
 * Calculate distance between two coordinates using the Haversine formula
 * @param lat1 Latitude of first point in degrees
 * @param lon1 Longitude of first point in degrees
 * @param lat2 Latitude of second point in degrees
 * @param lon2 Longitude of second point in degrees
 * @returns Distance in meters
 */
function haversineDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371000; // Earth radius in meters
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c; // Distance in meters
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Parse request body
    const locationUpdate: VehicleLocation = await req.json();
    const { vehicle_id, latitude, longitude, timestamp } = locationUpdate;

    // Validate input
    if (!vehicle_id || latitude === undefined || longitude === undefined) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Fetch all geofences assigned to this vehicle
    const { data: assignments, error: assignmentsError } = await supabase
      .from("geofence_assignments")
      .select("geofence_id")
      .eq("vehicle_id", vehicle_id);

    if (assignmentsError) {
      throw new Error(`Failed to fetch assignments: ${assignmentsError.message}`);
    }

    if (!assignments || assignments.length === 0) {
      // No geofences assigned to this vehicle
      return new Response(
        JSON.stringify({ message: "No geofences assigned to vehicle" }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const geofenceIds = assignments.map((a) => a.geofence_id);

    // Fetch geofence details
    const { data: geofences, error: geofencesError } = await supabase
      .from("geofences")
      .select("*")
      .in("geofence_id", geofenceIds);

    if (geofencesError) {
      throw new Error(`Failed to fetch geofences: ${geofencesError.message}`);
    }

    const eventsToCreate: GeofenceEvent[] = [];

    // Process each assigned geofence
    for (const geofence of geofences as Geofence[]) {
      // Calculate distance using haversine formula
      const distance = haversineDistance(
        latitude,
        longitude,
        geofence.latitude,
        geofence.longitude
      );

      const isInside = distance <= geofence.radius;

      // Check previous status by finding the most recent event
      const { data: lastEvent } = await supabase
        .from("geofence_events")
        .select("event_type, timestamp")
        .eq("vehicle_id", vehicle_id)
        .eq("geofence_id", geofence.geofence_id)
        .order("timestamp", { ascending: false })
        .limit(1)
        .single();

      const wasInside = lastEvent?.event_type === "entry";

      // Detect entry event
      if (isInside && !wasInside) {
        eventsToCreate.push({
          geofence_id: geofence.geofence_id,
          vehicle_id,
          event_type: "entry",
          timestamp: timestamp || new Date().toISOString(),
          latitude,
          longitude,
        });
      }

      // Detect exit event
      if (!isInside && wasInside) {
        // Calculate dwell time
        let dwellTime: number | undefined;
        if (lastEvent?.timestamp) {
          const entryTime = new Date(lastEvent.timestamp).getTime();
          const exitTime = new Date(timestamp || new Date()).getTime();
          dwellTime = Math.floor((exitTime - entryTime) / 1000); // Convert to seconds
        }

        eventsToCreate.push({
          geofence_id: geofence.geofence_id,
          vehicle_id,
          event_type: "exit",
          timestamp: timestamp || new Date().toISOString(),
          latitude,
          longitude,
          dwell_time: dwellTime,
        });
      }
    }

    // Insert all detected events
    if (eventsToCreate.length > 0) {
      const { error: insertError } = await supabase
        .from("geofence_events")
        .insert(eventsToCreate);

      if (insertError) {
        throw new Error(`Failed to insert events: ${insertError.message}`);
      }

      // Send notifications for each event
      // Prioritize restricted geofences
      const sortedEvents = [...eventsToCreate].sort((a, b) => {
        const geofenceA = (geofences as Geofence[]).find(
          (g) => g.geofence_id === a.geofence_id
        );
        const geofenceB = (geofences as Geofence[]).find(
          (g) => g.geofence_id === b.geofence_id
        );

        // Restricted geofences have higher priority
        if (geofenceA?.type === "restricted" && geofenceB?.type !== "restricted") {
          return -1;
        }
        if (geofenceA?.type !== "restricted" && geofenceB?.type === "restricted") {
          return 1;
        }
        return 0;
      });

      // Send notifications for each event
      const notificationPromises = sortedEvents.map(async (event) => {
        try {
          const notificationUrl = `${supabaseUrl}/functions/v1/send-geofence-notification`;
          const response = await fetch(notificationUrl, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${supabaseKey}`,
            },
            body: JSON.stringify({
              geofence_id: event.geofence_id,
              vehicle_id: event.vehicle_id,
              event_type: event.event_type,
              timestamp: event.timestamp,
              dwell_time: event.dwell_time,
            }),
          });

          if (!response.ok) {
            const errorText = await response.text();
            console.error(
              `Failed to send notification for event ${event.event_type}:`,
              errorText
            );
          }
        } catch (error) {
          console.error(
            `Error sending notification for event ${event.event_type}:`,
            error
          );
          // Don't throw - continue processing other notifications
        }
      });

      // Wait for all notifications to be sent
      await Promise.all(notificationPromises);
    }

    return new Response(
      JSON.stringify({
        message: "Monitoring completed",
        events_created: eventsToCreate.length,
        events: eventsToCreate,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error in monitor-geofences:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
