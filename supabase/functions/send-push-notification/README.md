# Push Notification Edge Function Setup

This Edge Function sends APNs push notifications when a row is inserted into `public.notifications`.

## Prerequisites

### 1. Apple Developer Portal — Create APNs Key

1. Go to [Apple Developer Portal → Certificates, Identifiers & Profiles → Keys](https://developer.apple.com/account/resources/authkeys/list)
2. Click **+** to create a new key
3. Name it "Fleet Management APNs Key"
4. Check **Apple Push Notifications service (APNs)**
5. Click **Continue** → **Register**
6. **Download** the `.p8` file (e.g., `AuthKey_ABC123XYZ.p8`) — you can only download it once
7. Note the **Key ID** (10 characters, e.g., `ABC123XYZ`)
8. Note your **Team ID** (10 characters, found in the top-right of the portal)

### 2. Set Environment Variables in Supabase

Go to your Supabase Dashboard → **Edge Functions** → **Secrets** and add:

| Secret Name | Value | Example |
|---|---|---|
| `APNS_KEY_ID` | Your Key ID from step 1.7 | `ABC123XYZ` |
| `APNS_TEAM_ID` | Your Team ID from step 1.8 | `DEF456UVW` |
| `APNS_PRIVATE_KEY` | Full contents of the `.p8` file | `-----BEGIN PRIVATE KEY-----\nMIGT...` |
| `APNS_BUNDLE_ID` | Your app's bundle identifier | `com.yourcompany.FleetManagementSystem` |
| `APNS_ENVIRONMENT` | `sandbox` for dev, `production` for App Store | `sandbox` |

**Note**: For `APNS_PRIVATE_KEY`, copy the entire `.p8` file contents including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines.

### 3. Deploy the Edge Function

```bash
cd supabase
supabase functions deploy send-push-notification
```

### 4. Create a Database Webhook

Go to Supabase Dashboard → **Database** → **Webhooks** → **Create a new hook**:

- **Name**: `send_push_on_notification_insert`
- **Table**: `public.notifications`
- **Events**: `INSERT`
- **Type**: `HTTP Request`
- **Method**: `POST`
- **URL**: `https://<your-project-ref>.supabase.co/functions/v1/send-push-notification`
- **HTTP Headers**:
  - `Authorization`: `Bearer <your-service-role-key>` (get from Supabase Dashboard → Settings → API)
  - `Content-Type`: `application/json`

Click **Create webhook**.

### 5. Test

1. Run the iOS app on a physical device (push doesn't work in Simulator)
2. Sign in as any user
3. Insert a test notification via Supabase SQL Editor:

```sql
INSERT INTO public.notifications (recipient_id, title, message, type)
VALUES (
    '<user_id_from_auth_users>',
    'Test Push',
    'This is a test push notification',
    'alert'
);
```

You should receive a push notification on the device.

## Troubleshooting

- **No push received**: Check the Edge Function logs in Supabase Dashboard → Edge Functions → Logs
- **"BadDeviceToken" error**: You're using a sandbox APNs key but the app is signed with a production certificate (or vice versa). Match `APNS_ENVIRONMENT` to your build configuration.
- **"Unregistered" error**: The device token is stale. The Edge Function automatically deletes it from `push_tokens`.
- **Push works but no banner**: Check that `UNUserNotificationCenter.current().delegate` is set (already done in `NotificationManager.init()`).

## Architecture

```
[iOS App] → registers with APNs → receives device token
    ↓
[NotificationManager] → uploads token to Supabase → push_tokens table
    ↓
[User action] → inserts row into notifications table
    ↓
[Database Webhook] → triggers Edge Function
    ↓
[Edge Function] → reads push_tokens → sends APNs HTTP/2 request
    ↓
[APNs] → delivers push to device
    ↓
[iOS App] → UNUserNotificationCenterDelegate → displays banner / handles tap
```
