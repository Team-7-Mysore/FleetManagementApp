// Supabase Edge Function: send-geofence-notification
// Sends notifications to fleet managers based on geofence events

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface NotificationRequest {
  geofence_id: string;
  vehicle_id: string;
  event_type: "entry" | "exit";
  timestamp: string;
  dwell_time?: number;
}

interface Geofence {
  geofence_id: string;
  name: string;
  type: "depot" | "delivery" | "restricted";
}

interface Vehicle {
  vehicle_id: string;
  make?: string;
  model?: string;
  license_plate?: string;
}

interface FleetManager {
  user_id: string;
}

/**
 * Format notification message based on event type and geofence type
 */
function formatNotificationMessage(
  geofence: Geofence,
  vehicle: Vehicle,
  request: NotificationRequest
): { title: string; body: string } {
  const vehicleName =
    vehicle.license_plate ||
    `${vehicle.make || ""} ${vehicle.model || ""}`.trim() ||
    "Vehicle";

  const eventAction = request.event_type === "entry" ? "entered" : "exited";

  let title = "";
  let body = "";

  switch (geofence.type) {
    case "depot":
      if (request.event_type === "entry") {
        title = "Vehicle Arrived at Depot";
        body = `${vehicleName} has entered ${geofence.name}`;
      } else {
        const dwellText = request.dwell_time
          ? ` after ${formatDwellTime(request.dwell_time)}`
          : "";
        title = "Vehicle Departed from Depot";
        body = `${vehicleName} has exited ${geofence.name}${dwellText}`;
      }
      break;

    case "delivery":
      if (request.event_type === "entry") {
        title = "Vehicle Arrived at Delivery Location";
        body = `${vehicleName} has entered ${geofence.name}`;
      } else {
        const dwellText = request.dwell_time
          ? ` after ${formatDwellTime(request.dwell_time)}`
          : "";
        title = "Vehicle Departed from Delivery Location";
        body = `${vehicleName} has exited ${geofence.name}${dwellText}`;
      }
      break;

    case "restricted":
      if (request.event_type === "entry") {
        title = "⚠️ Restricted Zone Entry Alert";
        body = `${vehicleName} has entered restricted zone: ${geofence.name}`;
      } else {
        const dwellText = request.dwell_time
          ? ` after ${formatDwellTime(request.dwell_time)}`
          : "";
        title = "Restricted Zone Exit";
        body = `${vehicleName} has exited restricted zone: ${geofence.name}${dwellText}`;
      }
      break;
  }

  return { title, body };
}

/**
 * Format dwell time in human-readable format
 */
function formatDwellTime(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);

  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  } else if (minutes > 0) {
    return `${minutes}m`;
  } else {
    return `${seconds}s`;
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Parse request body
    const request: NotificationRequest = await req.json();
    const { geofence_id, vehicle_id, event_type, timestamp, dwell_time } =
      request;

    // Validate input
    if (!geofence_id || !vehicle_id || !event_type) {
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

    // Fetch geofence details
    const { data: geofence, error: geofenceError } = await supabase
      .from("geofences")
      .select("*")
      .eq("geofence_id", geofence_id)
      .single();

    if (geofenceError || !geofence) {
      throw new Error(
        `Failed to fetch geofence: ${geofenceError?.message || "Not found"}`
      );
    }

    // Fetch vehicle details
    const { data: vehicle, error: vehicleError } = await supabase
      .from("vehicles")
      .select("vehicle_id, make, model, license_plate")
      .eq("vehicle_id", vehicle_id)
      .single();

    if (vehicleError || !vehicle) {
      throw new Error(
        `Failed to fetch vehicle: ${vehicleError?.message || "Not found"}`
      );
    }

    // Fetch all fleet managers
    const { data: fleetManagers, error: managersError } = await supabase
      .from("user_profiles")
      .select("user_id")
      .eq("role", "fleet_manager");

    if (managersError) {
      throw new Error(
        `Failed to fetch fleet managers: ${managersError.message}`
      );
    }

    if (!fleetManagers || fleetManagers.length === 0) {
      return new Response(
        JSON.stringify({ message: "No fleet managers found" }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Format notification message
    const message = formatNotificationMessage(
      geofence as Geofence,
      vehicle as Vehicle,
      request
    );

    // Set priority based on geofence type
    const priority = geofence.type === "restricted" ? "high" : "normal";

    // Create notification records for each fleet manager
    const notifications = fleetManagers.map((manager: FleetManager) => ({
      user_id: manager.user_id,
      title: message.title,
      body: message.body,
      priority: priority,
      type: "geofence_event",
      data: {
        geofence_id,
        vehicle_id,
        event_type,
        timestamp,
        dwell_time,
      },
      is_read: false,
      created_at: new Date().toISOString(),
    }));

    // Insert notifications
    const { error: insertError } = await supabase
      .from("notifications")
      .insert(notifications);

    if (insertError) {
      throw new Error(`Failed to insert notifications: ${insertError.message}`);
    }

    return new Response(
      JSON.stringify({
        message: "Notifications sent successfully",
        recipients: fleetManagers.length,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error in send-geofence-notification:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
