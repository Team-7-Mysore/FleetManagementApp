# Supabase Edge Functions

This directory contains Supabase Edge Functions for the Fleet Management System's Geofencing feature.

## Functions

### monitor-geofences

**Purpose**: Monitors vehicle location updates and detects geofence entry/exit events.

**Trigger**: Called by database trigger on `vehicle_locations` table INSERT/UPDATE operations.

**Request Body**:
```json
{
  "vehicle_id": "uuid",
  "latitude": 37.7749,
  "longitude": -122.4194,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

**Response**:
```json
{
  "message": "Monitoring completed",
  "events_created": 2,
  "events": [
    {
      "geofence_id": "uuid",
      "vehicle_id": "uuid",
      "event_type": "entry",
      "timestamp": "2024-01-15T10:30:00Z",
      "latitude": 37.7749,
      "longitude": -122.4194
    }
  ]
}
```

**Features**:
- Uses haversine formula for accurate distance calculation (Earth radius: 6,371,000 meters)
- Processes only assigned geofences for each vehicle
- Detects entry events when vehicle moves inside geofence boundary
- Detects exit events when vehicle moves outside geofence boundary
- Calculates dwell time for exit events (duration between entry and exit)
- Prioritizes restricted geofences for high-priority alerts
- Automatically triggers notifications for each event

**Performance**:
- Target: < 5 seconds per vehicle processing time
- Supports monitoring at least 100 vehicles simultaneously
- Supports at least 500 active geofences

### send-geofence-notification

**Purpose**: Sends notifications to fleet managers based on geofence events.

**Trigger**: Called by `monitor-geofences` function for each detected event.

**Request Body**:
```json
{
  "geofence_id": "uuid",
  "vehicle_id": "uuid",
  "event_type": "entry",
  "timestamp": "2024-01-15T10:30:00Z",
  "dwell_time": 3600
}
```

**Response**:
```json
{
  "message": "Notifications sent successfully",
  "recipients": 5
}
```

**Features**:
- Fetches geofence and vehicle details from database
- Fetches all fleet managers from user_profiles table
- Formats notification message based on event type and geofence type
- Sets priority to 'high' for restricted geofences, 'normal' for others
- Inserts notification records for each fleet manager
- Includes dwell time in exit notifications

**Notification Messages**:

**Depot Entry**:
- Title: "Vehicle Arrived at Depot"
- Body: "{Vehicle} has entered {Geofence Name}"

**Depot Exit**:
- Title: "Vehicle Departed from Depot"
- Body: "{Vehicle} has exited {Geofence Name} after {Dwell Time}"

**Delivery Entry**:
- Title: "Vehicle Arrived at Delivery Location"
- Body: "{Vehicle} has entered {Geofence Name}"

**Delivery Exit**:
- Title: "Vehicle Departed from Delivery Location"
- Body: "{Vehicle} has exited {Geofence Name} after {Dwell Time}"

**Restricted Entry**:
- Title: "⚠️ Restricted Zone Entry Alert"
- Body: "{Vehicle} has entered restricted zone: {Geofence Name}"
- Priority: HIGH

**Restricted Exit**:
- Title: "Restricted Zone Exit"
- Body: "{Vehicle} has exited restricted zone: {Geofence Name} after {Dwell Time}"

## Deployment

### Prerequisites
- Supabase CLI installed: `npm install -g supabase`
- Supabase project initialized: `supabase init`
- Supabase linked to project: `supabase link --project-ref <project-ref>`

### Deploy Functions
```bash
# Deploy all functions
supabase functions deploy

# Deploy specific function
supabase functions deploy monitor-geofences
supabase functions deploy send-geofence-notification
```

### Set Environment Variables
```bash
# Set in Supabase Dashboard > Edge Functions > Settings
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
```

## Testing

### Run Haversine Tests
```bash
deno test supabase/functions/monitor-geofences/haversine.test.ts
```

### Test monitor-geofences Locally
```bash
supabase functions serve monitor-geofences

# In another terminal
curl -X POST http://localhost:54321/functions/v1/monitor-geofences \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <anon-key>" \
  -d '{
    "vehicle_id": "uuid",
    "latitude": 37.7749,
    "longitude": -122.4194,
    "timestamp": "2024-01-15T10:30:00Z"
  }'
```

### Test send-geofence-notification Locally
```bash
supabase functions serve send-geofence-notification

# In another terminal
curl -X POST http://localhost:54321/functions/v1/send-geofence-notification \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <anon-key>" \
  -d '{
    "geofence_id": "uuid",
    "vehicle_id": "uuid",
    "event_type": "entry",
    "timestamp": "2024-01-15T10:30:00Z"
  }'
```

## Error Handling

Both functions implement comprehensive error handling:

1. **Input Validation**: Validates required fields and returns 400 Bad Request for invalid input
2. **Database Errors**: Catches and logs database query errors
3. **Network Errors**: Handles notification sending failures without blocking event processing
4. **Logging**: Logs all errors to console for monitoring and debugging

## Monitoring

Monitor function execution in Supabase Dashboard:
- Navigate to Edge Functions > Logs
- View execution time, error rate, and invocation count
- Set up alerts for high error rates or slow execution times

## Requirements Mapping

**monitor-geofences**:
- Requirements: 6.1, 6.2, 6.5, 7.1, 7.2, 7.5, 18.1

**send-geofence-notification**:
- Requirements: 8.1, 8.2, 9.1, 9.2, 10.1, 10.2, 11.1, 11.2, 12.1, 12.2

**Integration**:
- Requirements: 8.1, 9.1, 10.1, 11.1, 18.4
