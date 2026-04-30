import { serve } from "https://deno.land/std/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
)

serve(async (req) => {
  try {
    const body = await req.json()

    const { data: vehicle, error: vehicleError } = await supabase
      .from("vehicles")
      .upsert(
        {
          vehicle_name: body.vehicleName,
          number_plate: body.registrationNumber,
          vin: body.vin,
          brand: body.brand,
          manufacturer: body.manufacturer,
          model: body.model,
          model_year: body.model_year,
          vehicle_type: body.vehicleType,
          fuel_type: body.fuelType,
          image_url: body.image_url,
          registration_no: body.rc_number,
          registration_date: body.registrationDate,
          puc_expiry_date: body.pucExpiry,
          rc_expiry_date: body.rcExpiry,
          has_rc: (body.documents ?? []).some((doc: { type?: string }) => doc.type?.toUpperCase() === "RC"),
          has_insurance: (body.documents ?? []).some((doc: { type?: string }) => doc.type?.toUpperCase() === "INSURANCE"),
          has_puc: (body.documents ?? []).some((doc: { type?: string }) => doc.type?.toUpperCase() === "PUC"),
          updated_at: new Date().toISOString(),
        },
        { onConflict: "number_plate" },
      )
      .select("vehicle_id")
      .single()

    if (vehicleError) throw vehicleError

    if (body.documents?.length) {
      const normalizedTypes = body.documents.map((doc: { type: string }) => doc.type.toUpperCase())

      const { error: deleteError } = await supabase
        .from("vehicle_documents")
        .delete()
        .eq("vehicle_id", vehicle.vehicle_id)
        .in("document_type", normalizedTypes)

      if (deleteError) throw deleteError

      const docsToInsert = body.documents.map((doc: { type: string; url: string; name?: string; size?: number | null }) => ({
        vehicle_id: vehicle.vehicle_id,
        document_type: doc.type.toUpperCase(),
        file_url: doc.url,
        file_name: doc.name || `${doc.type}_doc.pdf`,
        file_size: doc.size ?? null,
      }))

      const { error: docError } = await supabase
        .from("vehicle_documents")
        .insert(docsToInsert)

      if (docError) throw docError
    }

    return new Response(
      JSON.stringify({ success: true, vehicle_id: vehicle.vehicle_id }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : "Unknown error" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    )
  }
})
