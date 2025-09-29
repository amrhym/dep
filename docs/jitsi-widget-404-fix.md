# 🚨 Fix: Jitsi Widget 404 Error

## Problem
Widget calls Jitsi endpoint but gets **404 Not Found**:
```
POST http://localhost:3000/api/v1/widget/integrations/jitsi/create_a_meeting → 404
```

Console shows smart fallback working:
```javascript
integration.js:56 POST .../jitsi/create_a_meeting 404 (Not Found)
integration.js:58 Jitsi integration failed, trying Dyte fallback: 404
integration.js:60 POST .../dyte/create_a_meeting 422 (Unprocessable Content) 
integration.js:62 Both integrations failed. Jitsi error: 404 Dyte error: 422
```

## Root Cause
- ✅ **Routes exist**: `bundle exec rails routes` shows Jitsi widget routes registered
- ✅ **Controller exists**: File at `app/controllers/api/v1/widget/integrations/jitsi_controller.rb`
- ✅ **Controller loads**: `rails runner` can load the class
- ❌ **Runtime issue**: Rails not routing to controller in development

## Solution

### 1. Restart Rails Server
The most common cause is Rails not hot-reloading new controllers properly:

```bash
# Stop current server (Ctrl+C)
# Then restart
bundle exec rails server
# OR if using overmind
overmind restart
```

### 2. Verify Environment Variables
Ensure Jitsi environment variables are set:

```bash
# Check if variables are loaded
echo $JITSI_BASE_URL
echo $VITE_JITSI_URL  
echo $VITE_JITSI_FORCE_PRIMARY

# Should output:
# https://jitsi.xdec.io
# https://jitsi.xdec.io  
# true
```

### 3. Create Jitsi Integration Hook (Alternative)
If the 404 persists, create a Jitsi integration in the admin panel:

1. **Go to Settings > Integrations**
2. **Find "Jitsi Meet"**  
3. **Click "Connect"**
4. **Save** (leave settings empty for basic functionality)

This ensures Jitsi appears in `appIntegrations` array and the video call button activates properly.

### 4. Test Dashboard First
Before testing widget, verify dashboard works:

```bash
curl 'http://localhost:3000/api/v1/accounts/1/integrations/jitsi/create_a_meeting' \
  -H 'Authorization: Bearer <agent_token>' \
  -H 'Content-Type: application/json' \
  -d '{"conversation_id":8}'
```

Should return:
```json
{
  "success": true,
  "data": {
    "room_name": "chatwoot-8-abc123",
    "created_by": 1,
    "created_at": "2023-09-28T12:00:00Z"
  }
}
```

## Expected Behavior After Fix

### Widget Console Logs (Success):
```javascript
// Should NOT see 404 error
POST /api/v1/widget/integrations/jitsi/create_a_meeting → 200 OK
```

### Widget Console Logs (Graceful Fallback):
```javascript  
// If Jitsi unavailable, should fall back to Dyte
POST /api/v1/widget/integrations/jitsi/create_a_meeting → 401/500
Jitsi integration failed, trying Dyte fallback: 401
POST /api/v1/widget/integrations/dyte/create_a_meeting → 200 OK
```

## Verification Steps

1. **Restart server** ✅
2. **Test widget video call button** ✅  
3. **Check browser console** - should see 200 or graceful fallback ✅
4. **Verify Jitsi room creation** - should get `chatwoot-X-abc123` room name ✅
5. **Test iframe embedding** - should open Jitsi room in panel ✅

## Alternative Quick Fix

If restart doesn't work, temporarily force the widget to use Dyte by reverting the smart detection:

```javascript
// In app/javascript/widget/components/HeaderActions.vue
// Replace:
const { data } = await IntegrationAPIClient.createVideoMeeting();

// With:
const { data } = await IntegrationAPIClient.createDyteMeeting();
```

This bypasses the 404 issue and uses the working Dyte integration while debugging the Jitsi widget controller.

## Summary

The issue is likely a **Rails development server** not picking up the new widget controller properly. A server restart should resolve the 404 error and allow the Jitsi widget endpoints to work correctly. ✅