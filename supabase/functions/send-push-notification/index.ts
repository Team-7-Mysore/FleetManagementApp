/**
 * Supabase Edge Function: send-push-notification
 *
 * Triggered by a Postgres webhook on INSERT into public.notifications.
 * Looks up the recipient's APNs device tokens and sends a push via APNs HTTP/2.
 *
 * Required environment variables (set in Supabase Dashboard → Edge Functions → Secrets):
 *   SUPABASE_URL            - Your project URL
 *   SUPABASE_SERVICE_ROLE_KEY - Service role key (to bypass RLS)
 *   APNS_KEY_ID             - 10-character Key ID from Apple Developer portal
 *   APNS_TEAM_ID            - 10-character Team ID from Apple Developer portal
 *   APNS_PRIVATE_KEY        - Contents of the .p8 file (AuthKey_XXXXXXXX.p8)
 *   APNS_BUNDLE_ID          - Your app's bundle identifier (e.g. com.yourcompany.FleetManagementSystem)
 *   APNS_ENVIRONMENT        - "production" or "sandbox" (use "sandbox" for development)
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!;
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID")!;
const APNS_ENVIRONMENT = Deno.env.get("APNS_ENVIRONMENT") ?? "sandbox";

const APNS_HOST =
  APNS_ENVIRONMENT === "production"
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";

// ---------------------------------------------------------------------------
// JWT generation for APNs token-based auth
// ---------------------------------------------------------------------------
let cachedJwt: { token: string; issuedAt: number } | null = null;

async function getApnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  // Reuse token if it's less than 55 minutes old (APNs tokens expire after 60 min)
  if (cachedJwt && now - cachedJwt.issuedAt < 55 * 60) {
    return cachedJwt.token;
  }

  // Import the ECDSA P-256 private key from the .p8 PEM string
  const pemBody = APNS_PRIVATE_KEY.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\n/g, "");
  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const token = await create(
    { alg: "ES256", kid: APNS_KEY_ID },
    { iss: APNS_TEAM_ID, iat: getNumericDate(0) },
    cryptoKey
  );

  cachedJwt = { token, issuedAt: now };
  return token;
}

// ---------------------------------------------------------------------------
// Send a single APNs push
// ---------------------------------------------------------------------------
async function sendApnsPush(
  deviceToken: string,
  title: string,
  body: string,
  data: Record<string, unknown> = {}
): Promise<{ success: boolean; error?: string }> {
  const jwt = await getApnsJwt();

  const payload = {
    aps: {
      alert: { title, body },
      sound: "default",
      badge: 1,
    },
    ...data,
  };

  const url = `${APNS_HOST}/3/device/${deviceToken}`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": APNS_BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (response.status === 200) {
    return { success: true };
  }

  const errorBody = await response.json().catch(() => ({}));
  const reason = (errorBody as { reason?: string }).reason ?? `HTTP ${response.status}`;

  // BadDeviceToken means the token is stale — caller should delete it
  return { success: false, error: reason };
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------
Deno.serve(async (req) => {
  try {
    const body = await req.json();

    // Supabase Database Webhooks send { type, table, record, old_record, schema }
    const record = body?.record;
    if (!record) {
      return new Response(JSON.stringify({ error: "No record in payload" }), { status: 400 });
    }

    const recipientId: string = record.recipient_id;
    const title: string = record.title ?? "Fleet Management";
    const message: string = record.message ?? "";
    const notificationId: string = record.id;
    const relatedEntityId: string | null = record.related_entity_id ?? null;

    if (!recipientId) {
      return new Response(JSON.stringify({ error: "No recipient_id" }), { status: 400 });
    }

    // Use service role to bypass RLS and read push tokens
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: tokens, error: tokenError } = await supabase
      .from("push_tokens")
      .select("id, token")
      .eq("user_id", recipientId)
      .eq("platform", "ios");

    if (tokenError) {
      console.error("Failed to fetch push tokens:", tokenError);
      return new Response(JSON.stringify({ error: tokenError.message }), { status: 500 });
    }

    if (!tokens || tokens.length === 0) {
      console.log(`No push tokens for user ${recipientId}`);
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    const customData: Record<string, unknown> = {
      notification_id: notificationId,
    };
    if (relatedEntityId) {
      customData.related_entity_id = relatedEntityId;
    }

    const staleTokenIds: string[] = [];
    let sentCount = 0;

    await Promise.all(
      tokens.map(async (row: { id: string; token: string }) => {
        const result = await sendApnsPush(row.token, title, message, customData);
        if (result.success) {
          sentCount++;
        } else {
          console.warn(`APNs error for token ${row.token}: ${result.error}`);
          // Mark stale tokens for cleanup
          if (result.error === "BadDeviceToken" || result.error === "Unregistered") {
            staleTokenIds.push(row.id);
          }
        }
      })
    );

    // Clean up stale tokens
    if (staleTokenIds.length > 0) {
      await supabase.from("push_tokens").delete().in("id", staleTokenIds);
      console.log(`Removed ${staleTokenIds.length} stale push token(s)`);
    }

    return new Response(JSON.stringify({ sent: sentCount }), { status: 200 });
  } catch (err) {
    console.error("Edge function error:", err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
