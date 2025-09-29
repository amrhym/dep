# Jitsi Integration Fix Summary

## 🚨 Fixed Issues

### Backend Fixes
1. **Created Widget Controller**: Added `app/controllers/api/v1/widget/integrations/jitsi_controller.rb`
2. **Added Widget Routes**: Added Jitsi routes to widget integrations namespace in `config/routes.rb`
3. **Fixed Service Dependencies**: Updated `Integrations::JitsiService` to work without requiring hooks
4. **Fixed Controller Authorization**: Scoped `before_action :authorize_request` to specific actions

### Frontend Fixes
1. **Dashboard Detection**: Updated `VideoCallButton.vue` to detect Jitsi integration even without hooks
2. **Widget API Client**: Added Jitsi methods to `app/javascript/widget/api/integration.js`
3. **Integration Detection**: Enhanced logic to prefer configured integrations but fallback to available ones
4. **Error Handling**: Added proper error messages for Jitsi in locales

### Routes Verified
```bash
# Dashboard endpoints
POST /api/v1/accounts/:account_id/integrations/jitsi/create_a_meeting
POST /api/v1/accounts/:account_id/integrations/jitsi/add_participant_to_meeting

# Widget endpoints  
POST /api/v1/widget/integrations/jitsi/create_a_meeting
POST /api/v1/widget/integrations/jitsi/add_participant_to_meeting
```

## 🧪 Testing Instructions

### Prerequisites
1. Ensure `JITSI_BASE_URL=https://jitsi.xdec.io` in `.env`
2. Ensure `VITE_JITSI_URL=https://jitsi.xdec.io` in `.env`

### Test Scenario 1: With Jitsi Hook Configured
1. Go to **Settings > Integrations**
2. Find "Jitsi Meet" and click **"Connect"**
3. Save (settings can be empty for basic functionality)
4. Go to a conversation
5. Click the video call button
6. Should create a Jitsi meeting and render iframe

### Test Scenario 2: Without Hook (Fallback Mode)
1. Ensure no Jitsi hook exists in database
2. Verify Jitsi integration appears in Settings > Integrations
3. Video call button should still appear (fallback detection)
4. Clicking should create meeting with default settings

### Expected API Calls

**Dashboard Flow:**
```http
POST /api/v1/accounts/1/integrations/jitsi/create_a_meeting
Content-Type: application/json
Authorization: Bearer <agent_token>

{
  "conversation_id": 7
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "room_name": "chatwoot-7-a1b2c3d4e5f6",
    "created_by": 1,
    "created_at": "2023-09-28T11:45:00.000Z"
  }
}
```

**Widget Flow:**
```http
POST /api/v1/widget/integrations/jitsi/create_a_meeting?website_token=abc123
X-Auth-Token: <visitor_token>
```

### Expected Frontend Behavior

1. **Dashboard**: 
   - Jitsi bubble renders with iframe to `https://jitsi.xdec.io/chatwoot-7-a1b2c3d4e5f6`
   - Toolbar has Fullscreen, PiP, Pop-out, Leave controls

2. **Widget**:
   - IntegrationCard detects `room_name` in message data → identifies as Jitsi
   - Click "Join" → JitsiPanel opens with same iframe URL
   - Both participants join same room

## 🔧 Key Changes Made

### Service Layer
```ruby
# app/services/integrations/jitsi_service.rb
def jitsi_hook
  @jitsi_hook ||= account.hooks.find_by(app_id: 'jitsi')  # find_by, not find_by!
end

def jitsi_client
  if jitsi_hook&.settings
    # Use configured settings
  else
    # Use default configuration for hookless operation
    @jitsi_client ||= Jitsi.new(nil, nil)
  end
end
```

### Frontend Detection
```javascript
// app/javascript/dashboard/components/widgets/VideoCallButton.vue
videoIntegration() {
  // First check for configured integrations
  let integration = this.appIntegrations.find(
    integration => ['dyte', 'jitsi'].includes(integration.id) && !!integration.hooks.length
  );
  
  if (!integration) {
    // Fallback: Jitsi can work without hooks
    integration = this.appIntegrations.find(
      integration => integration.id === 'jitsi'
    );
  }
  
  return integration;
}
```

### Widget API
```javascript
// app/javascript/widget/api/integration.js
createJitsiMeeting: () => {
  const search = buildSearchParamsWithLocale(window.location.search);
  return API.post(`/api/v1/widget/integrations/jitsi/create_a_meeting${search}`);
},
```

## 🐛 Troubleshooting

### 401 Unauthorized Errors
- **Cause**: Agent doesn't have permission to access conversation's inbox
- **Fix**: Ensure agent is assigned to the inbox or has admin role

### 500 Internal Server Error  
- **Cause**: Service couldn't find required hook with find_by!
- **Fix**: Service now uses find_by and graceful fallbacks

### Integration Not Visible
- **Cause**: Jitsi not in appIntegrations array
- **Fix**: Verify Jitsi is defined in config/integration/apps.yml and appears in Settings > Integrations

### Wrong Endpoints Called
- **Cause**: Frontend still calling Dyte endpoints
- **Fix**: Integration detection now properly routes to Jitsi endpoints when Jitsi is configured

## 📋 Testing Checklist

- [ ] Jitsi appears in Settings > Integrations
- [ ] Can create Jitsi hook (even with empty settings)  
- [ ] Video call button appears in conversations
- [ ] Dashboard: Click button → creates meeting → renders Jitsi bubble
- [ ] Widget: IntegrationCard detects Jitsi type → Join button works
- [ ] Both iframe URLs point to same room on jitsi.xdec.io
- [ ] No 401/500 errors in network tab
- [ ] Room names are URL-safe format: `chatwoot-{id}-{hex}`

## 🎯 Integration Flow Summary

```
Agent clicks "Start Video Call"
    ↓
VideoCallButton detects videoIntegration.id === 'jitsi'  
    ↓
Calls JitsiAPI.createAMeeting(conversationId)
    ↓  
POST /api/v1/accounts/:id/integrations/jitsi/create_a_meeting
    ↓
JitsiController → JitsiService → creates message with room_name
    ↓
Message renders as Jitsi bubble in dashboard
    ↓
Same message appears in widget as IntegrationCard  
    ↓
Customer clicks "Join" → emits jitsi:join-room event
    ↓
JitsiPanel opens with iframe to https://jitsi.xdec.io/{room_name}
```

Both participants are now in the same Jitsi room! 🎉