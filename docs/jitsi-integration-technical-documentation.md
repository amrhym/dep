# Jitsi Meet Video Integration - Technical Documentation

## Overview

The Jitsi Meet integration enables video calling functionality in Chatwoot using the open-source Jitsi Meet video conferencing solution. This integration operates completely independently from Dyte, providing an alternative video calling solution that requires minimal configuration and no external API keys.

### Purpose
- Provide video calling capabilities between agents and customers
- Support both dashboard (agent-initiated) and widget (customer-joined) video calls
- Integrate seamlessly with Chatwoot's messaging system through integration messages
- Offer a self-hosted, privacy-focused alternative to cloud-based video solutions

### High-Level Architecture
```
Agent Dashboard → API Call → JitsiService → Message Creation → Real-time Broadcast
                                                    ↓
Widget Interface ← Event Listener ← Integration Card ← Message Rendering
```

The integration follows Chatwoot's standard integration pattern:
1. **Backend service** generates room names and creates integration messages
2. **Frontend components** render video interfaces and handle user interactions
3. **Real-time messaging** ensures both dashboard and widget stay synchronized

### Coexistence with Dyte
The Jitsi integration runs parallel to Dyte with no shared logic:
- **Separate controllers, services, and API clients**
- **Independent message types** (`type: 'jitsi'` vs `type: 'dyte'`)
- **Priority-based selection** in `VideoCallButton.vue` (Jitsi preferred when available)
- **Fallback mechanism** in widget API client (`createVideoMeeting()`)

## Backend Implementation

### Core Service: `app/services/integrations/jitsi_service.rb`

**Purpose**: Central service handling room creation, message generation, and URL building.

**Key Methods**:

#### `create_a_meeting(agent)`
- **Input**: Agent object (User model)
- **Output**: `{ success: true, data: meeting_data }` or error hash
- **Logic**:
  1. Generates unique room name using `generate_room_name`
  2. Creates localized meeting title using agent's name
  3. Builds meeting data hash with room_name, created_by, created_at
  4. Creates integration message via `create_a_jitsi_integration_message`
  5. Triggers real-time broadcast with `message.push_event_data`

```ruby
meeting_data = {
  room_name: "chatwoot-7-abc123",  # conversation_id + random hex
  created_by: agent.id,
  created_at: Time.current.iso8601
}
```

#### `add_participant_to_meeting(room_name)`
- **Input**: String room name from existing message
- **Output**: `{ meeting_url: "https://jitsi.xdec.io/room-name" }`
- **Logic**: Delegates to `jitsi_client.build_meeting_url()` for URL construction
- **Future**: Will include JWT token generation when authentication is implemented

#### `generate_room_name` (private)
- **Format**: `"chatwoot-#{conversation.id}-#{SecureRandom.hex(6)}"`
- **Purpose**: Creates unique, predictable room identifiers
- **Example**: `"chatwoot-42-1a2b3c4d5e6f"`

#### `create_a_jitsi_integration_message` (private)
Creates a `Message` record with:
- **content_type**: `:integrations`
- **content_attributes**: `{ type: 'jitsi', data: meeting_data }`
- **content**: Localized meeting title (e.g., "John Doe has started a meeting")
- **message_type**: `:outgoing` (appears as agent-sent)

### Dashboard Controller: `app/controllers/api/v1/accounts/integrations/jitsi_controller.rb`

**Purpose**: Handles agent-initiated video calls from the dashboard interface.

**Endpoints**:

#### `POST /api/v1/accounts/:account_id/integrations/jitsi/create_a_meeting`
- **Authentication**: Requires logged-in agent (`Current.user`)
- **Authorization**: Checks agent can access conversation inbox (`authorize @conversation.inbox, :show?`)
- **Parameters**: `conversation_id` (display_id format)
- **Flow**:
  1. Fetches conversation by display_id
  2. Instantiates `JitsiService` with account and conversation
  3. Calls `create_a_meeting(Current.user)`
  4. Returns JSON response with meeting data or error

#### `POST /api/v1/accounts/:account_id/integrations/jitsi/add_participant_to_meeting`
- **Purpose**: Generate meeting URL for existing Jitsi message
- **Parameters**: `message_id`
- **Validation**: Ensures message is integration type with `type: 'jitsi'`
- **Response**: `{ meeting_url: "https://..." }` for iframe embedding

### Widget Controller: `app/controllers/api/v1/widget/integrations/jitsi_controller.rb`

**Purpose**: Handles visitor-initiated or visitor-joined video calls from the widget.

**Key Differences from Dashboard Controller**:
- **Authentication**: Uses widget session (`@web_widget`) instead of user session
- **Agent Resolution**: Picks first available account user as message sender
- **Error Handling**: More defensive (checks for missing agent, missing conversation)

#### `create_a_meeting`
- **Use Case**: When visitor initiates a call or auto-join after conversation creation
- **Agent Selection**: `@web_widget.inbox.account.users.first`
- **Conversation**: Retrieved from widget session or parameter

#### `add_participant_to_meeting`
- **Same logic as dashboard** but operates in widget authentication context
- **Used by**: `IntegrationCard.vue` when visitor clicks "Join Call"

### Core Client: `lib/jitsi.rb`

**Purpose**: Simple client for building Jitsi Meet URLs and future JWT authentication.

**Configuration**:
- **`@base_url`**: From `ENV['JITSI_BASE_URL']` (default: `'https://jitsi.xdec.io'`)
- **`@app_id`, `@secret_key`**: For future JWT implementation (currently unused)

#### `build_meeting_url(room_name)`
- **Current Implementation**: Simple URL concatenation
- **Format**: `"#{@base_url}/#{room_name}"`
- **Future**: Will append JWT token as query parameter

#### `generate_jwt_token` (commented out)
- **Purpose**: Will create signed JWT tokens for room authentication
- **Payload Structure**: Includes user info, room permissions, moderator status
- **Algorithm**: HS256 signing with secret key

### Routes Configuration: `config/routes.rb`

**Dashboard Routes** (line 281-286):
```ruby
resource :jitsi, controller: 'jitsi', only: [] do
  collection do
    post :create_a_meeting
    post :add_participant_to_meeting
  end
end
```

**Widget Routes** (line 382-387):
```ruby
resource :jitsi, controller: 'jitsi', only: [] do
  collection do
    post :create_a_meeting
    post :add_participant_to_meeting
  end
end
```

Both mount under their respective namespaces:
- Dashboard: `/api/v1/accounts/:account_id/integrations/jitsi/`
- Widget: `/api/v1/widget/integrations/jitsi/`

### Integration Registration

**Configuration**: `config/integration/apps.yml` (lines 204-239)

```yaml
jitsi:
  id: jitsi
  logo: jitsi.png
  i18n_key: jitsi
  action: /jitsi
  hook_type: account
  allow_multiple_hooks: false
  settings_json_schema:
    properties:
      app_id: { type: 'string' }
      secret_key: { type: 'string' }
    required: []  # Both optional for simple iframe embedding
  settings_form_schema:
    - label: 'App ID (Optional - for JWT auth)'
      type: 'text'
      name: 'app_id'
      help: 'Leave empty for simple iframe embedding without JWT authentication'
    - label: 'Secret Key (Optional - for JWT auth)'
      type: 'text'
      name: 'secret_key'
      help: 'Leave empty for simple iframe embedding without JWT authentication'
  visible_properties: []
```

**Key Features**:
- **Optional credentials**: Works without app_id/secret_key for simple embedding
- **Future-ready**: Schema supports JWT authentication when implemented
- **Account-level**: One integration per Chatwoot account

## Frontend Implementation

### Dashboard (Agent UI)

#### API Client: `app/javascript/dashboard/api/integrations/jitsi.js`

**Purpose**: HTTP client for dashboard-to-backend communication.

**Class Structure**:
```javascript
class JitsiAPI extends ApiClient {
  constructor() {
    super('integrations/jitsi', { accountScoped: true });
  }
}
```

**Methods**:

##### `createAMeeting(conversationId)`
- **HTTP**: `POST /api/v1/accounts/{id}/integrations/jitsi/create_a_meeting`
- **Payload**: `{ conversation_id: conversationId }`
- **Returns**: Axios promise with meeting data
- **Used by**: `VideoCallButton.vue` on button click

##### `addParticipantToMeeting(messageId)`
- **HTTP**: `POST /api/v1/accounts/{id}/integrations/jitsi/add_participant_to_meeting`
- **Payload**: `{ message_id: messageId }`
- **Returns**: `{ meeting_url: "..." }` for iframe source
- **Used by**: `Jitsi.vue` when agent joins existing call

#### Video Call Button: `app/javascript/dashboard/components/widgets/VideoCallButton.vue`

**Purpose**: Smart button that detects and initiates video calls using available integrations.

**Integration Detection Logic**:
```javascript
videoIntegration() {
  // 1. Force Jitsi if VITE_JITSI_FORCE_PRIMARY=true
  if (forceJitsi && jitsiExists) return jitsiIntegration;
  
  // 2. Prefer Jitsi with hooks
  if (jitsiWithHooks) return jitsiIntegration;
  
  // 3. Accept Jitsi without hooks (works with defaults)
  if (jitsiWithoutHooks) return jitsiIntegration;
  
  // 4. Fallback to Dyte with hooks
  if (dyteWithHooks) return dyteIntegration;
}
```

**Button Click Flow**:
```javascript
async onClick() {
  this.isLoading = true;
  try {
    if (this.videoIntegration?.id === 'jitsi') {
      await JitsiAPI.createAMeeting(this.conversationId);
    } else {
      await DyteAPI.createAMeeting(this.conversationId);  // Fallback
    }
  } catch (error) {
    // Show integration-specific error message
  }
}
```

#### Message Renderer: `app/javascript/dashboard/components-next/message/Message.vue`

**Purpose**: Routes integration messages to appropriate bubble components.

**Jitsi Detection** (lines 303-305):
```javascript
if (props.contentAttributes.type === 'jitsi') {
  return JitsiBubble;
}
```

**Integration with Message System**:
- Imports `JitsiBubble` component (line 36)
- Uses `componentToRender` computed property for dynamic component resolution
- Passes all message props to bubble component via Vue's component rendering

#### Jitsi Bubble: `app/javascript/dashboard/components-next/message/bubbles/Jitsi.vue`

**Purpose**: Renders Jitsi meeting interface with iframe embedding and controls.

**State Management**:
```javascript
const isLoading = ref(false);
const meetingUrl = ref('');  // Iframe source URL
const roomName = computed(() => 
  contentAttributes?.value?.data?.room_name || 
  contentAttributes?.value?.data?.roomName
);
```

**User Interface**:
- **Join Button**: Calls `joinTheCall()` to load meeting URL
- **Toolbar Controls**: Fullscreen, Picture-in-Picture, Pop-out, Leave
- **Iframe Container**: 420px height, full-width embedded Jitsi interface

**Key Methods**:

##### `joinTheCall()`
- Builds meeting URL using `buildJitsiURL(roomName, jwt)`
- Sets `meetingUrl.ref` to trigger iframe rendering
- Shows loading state during URL generation

##### `enterFullscreen()`
- Uses HTML5 Fullscreen API on panel container
- Provides immersive video calling experience

##### `requestPiP()`
- **Modern browsers**: Uses Document Picture-in-Picture API
- **Fallback**: Opens popup window with meeting URL
- **Cleanup**: Tracks PiP window for proper disposal

##### `leaveTheRoom()`
- Clears `meetingUrl` to hide iframe
- Stops video call without affecting message history

### Widget (Visitor UI)

#### Jitsi Panel: `app/javascript/widget/components/JitsiPanel.vue`

**Purpose**: Full-screen video interface for widget visitors.

**Lifecycle Management**:
```javascript
const isVisible = ref(false);    // Panel visibility state
const roomName = ref('');        // Current room being accessed
```

**Event-Driven Architecture**:
```javascript
onMounted(() => {
  emitter.on('jitsi:join-room', joinByRoom);
});

const joinByRoom = rn => {
  if (!rn) return;
  roomName.value = rn;
  isVisible.value = true;  // Opens panel
};
```

**User Controls**:
- **Close button**: Hides panel and clears room name
- **Fullscreen/PiP**: Same functionality as dashboard bubble
- **Pop-out**: Opens meeting in new window

**Styling**:
- **Fixed height**: 320px with max-height: 40vh
- **Full-width**: Spans entire widget width
- **Z-index**: High value (10) to overlay other content

#### Integration Card: `app/javascript/widget/components/template/IntegrationCard.vue`

**Purpose**: Renders "Join Call" buttons for existing video meetings.

**Integration Type Detection**:
```javascript
integrationType() {
  // Detects Jitsi vs Dyte based on message data structure
  if (this.meetingData?.room_name) {
    return 'jitsi';  // Jitsi uses room_name
  }
  return 'dyte';     // Dyte uses meeting_id
}
```

**Join Flow**:
```javascript
async joinTheCall() {
  if (this.integrationType === 'jitsi') {
    // Emit event to open JitsiPanel
    emitter.emit('jitsi:join-room', this.meetingData.room_name);
  } else {
    // Emit event to open DytePanel
    emitter.emit('dyte:join-message', this.messageId);
  }
}
```

**Auto-Join Support**:
- Listens for `jitsi:auto-join` events
- Automatically triggers `joinTheCall()` when messageId matches

#### Messages View: `app/javascript/widget/views/Messages.vue`

**Purpose**: Main widget conversation view that includes video panels.

**Template Structure** (lines 27-28):
```vue
<DytePanel />
<JitsiPanel />
<div class="flex flex-1 overflow-auto">
  <ConversationWrap :grouped-messages="groupedMessages" />
</div>
```

**Integration Strategy**:
- Both video panels are always present in DOM
- Visibility controlled by internal component state
- Ensures seamless switching between integration types

#### Widget API Client: `app/javascript/widget/api/integration.js`

**Purpose**: HTTP client for widget-to-backend communication with smart fallback logic.

**Jitsi-Specific Methods**:

##### `createJitsiMeeting()`
- **Endpoint**: `/api/v1/widget/integrations/jitsi/create_a_meeting`
- **Authentication**: Uses widget session (`cw_conversation` or `X-Auth-Token`)
- **Response**: Meeting data with room_name

##### `addParticipantToJitsiMeeting(messageId)`
- **Endpoint**: `/api/v1/widget/integrations/jitsi/add_participant_to_meeting`
- **Purpose**: Get meeting URL for existing Jitsi message
- **Usage**: Future enhancement for visitor-initiated joins

##### `createVideoMeeting()` (Smart Fallback)
- **Strategy**: Try Jitsi first, fallback to Dyte on failure
- **Error Handling**: Prefers Jitsi errors in final rejection
- **Used by**: `Home.vue` and `PreChatForm.vue` for auto-start functionality

### Shared Utilities

#### Integration Helper: `app/javascript/shared/helpers/IntegrationHelper.js`

**Purpose**: Shared utilities for URL building and authentication across dashboard and widget.

##### `buildJitsiURL(roomName, jwtToken = null)`
- **Base URL**: From `import.meta.env.VITE_JITSI_URL` or default `'https://meet.jit.si'`
- **Current**: Simple concatenation `"${baseUrl}/${roomName}"`
- **Future**: Will append JWT as query parameter `"${baseUrl}/${roomName}?jwt=${jwtToken}"`

##### `getJitsiAuthToken()`
- **Current Implementation**: Returns `null` (no authentication)
- **TODO Comment**: `[JITSI-AUTH]` - implement when backend supports JWT
- **Future**: Will return JWT token for authenticated room access

## Data Flow: End-to-End Examples

### Dashboard Initiated Call

1. **Agent Action**: Clicks "Start Video Call" button in conversation
2. **Frontend**: `VideoCallButton.vue` detects Jitsi integration is highest priority
3. **API Call**: `JitsiAPI.createAMeeting(conversationId)` → `POST /api/v1/accounts/1/integrations/jitsi/create_a_meeting`
4. **Backend Processing**:
   - `JitsiController#create_a_meeting` authorizes and fetches conversation
   - `JitsiService#create_a_meeting` generates room name `chatwoot-7-abc123`
   - Creates message with content_attributes: `{ type: 'jitsi', data: { room_name: 'chatwoot-7-abc123', created_by: 42, created_at: '2024-01-01T10:00:00Z' } }`
   - `message.push_event_data` broadcasts to all connected clients
5. **Real-time Update**: Dashboard receives new message via WebSocket
6. **Message Rendering**: `Message.vue` detects `type: 'jitsi'` → renders `Jitsi.vue`
7. **Video Interface**: `Jitsi.vue` shows "Click here to join" button
8. **Agent Join**: Click triggers `joinTheCall()` → `buildJitsiURL()` → iframe loads `https://jitsi.xdec.io/chatwoot-7-abc123`

### Widget Join Flow

1. **Message Display**: Widget receives same integration message via real-time sync
2. **Card Rendering**: `IntegrationCard.vue` detects `meetingData.room_name` exists → `integrationType = 'jitsi'`
3. **Join Button**: Shows "Click here to join" with Jitsi-specific styling
4. **Visitor Click**: `joinTheCall()` → `emitter.emit('jitsi:join-room', room_name)`
5. **Panel Activation**: `JitsiPanel.vue` receives event → sets `isVisible = true`
6. **URL Building**: `iframeSrc()` → `buildJitsiURL(roomName)` → same URL as dashboard
7. **Video Interface**: Panel opens with iframe, toolbar controls, and close button

### Auto-Start Flow (Advanced)

**Trigger**: `window.chatwootDyteAutoStart = true` before widget initialization

1. **Pre-chat Form**: User submits contact information
2. **Conversation Creation**: Widget creates new conversation via API
3. **Auto-Join Handler**: `PreChatForm.vue#handleConversationCreated()`
4. **Meeting Creation**: `IntegrationAPIClient.createJitsiMeeting()`
5. **Auto-Join Event**: `emitter.emit('jitsi:auto-join', messageId)`
6. **Card Response**: `IntegrationCard.vue` auto-triggers `joinTheCall()`
7. **Panel Opens**: Visitor automatically joins video call after form submission

## Configuration & Environment

### Environment Variables

#### Backend Configuration (`.env.example` lines 258-265)
```bash
# Jitsi server URL for meeting URL generation
JITSI_BASE_URL=https://jitsi.xdec.io

# Frontend environment variable (must match JITSI_BASE_URL)
VITE_JITSI_URL=https://jitsi.xdec.io

# Force Jitsi as primary integration over Dyte
VITE_JITSI_FORCE_PRIMARY=true
```

**Configuration Notes**:
- **`JITSI_BASE_URL`**: Used by backend `lib/jitsi.rb` for URL generation
- **`VITE_JITSI_URL`**: Used by frontend for consistent URL building
- **`VITE_JITSI_FORCE_PRIMARY`**: Development/testing flag to prioritize Jitsi

#### Admin UI Configuration

**Integration Setup**:
1. Navigate to Settings → Integrations
2. Find "Jitsi Meet" in available integrations
3. Click "Connect" (no credentials required for basic setup)
4. Optional: Configure App ID and Secret Key for future JWT authentication

**Runtime Detection**:
- `VideoCallButton.vue` checks `this.appIntegrations` for Jitsi entry
- Integration is enabled when present in `apps.yml` and not explicitly disabled
- No external API validation required (unlike Dyte)

### Internationalization

#### Backend Locales: `config/locales/en.yml` (lines 259-263)
```yaml
integration_apps:
  jitsi:
    name: 'Jitsi Meet'
    short_description: 'Start video/voice calls with customers using open-source Jitsi Meet.'
    description: 'Jitsi Meet is an open-source video conferencing solution that provides secure, high-quality video calls. With this integration, your agents can start video/voice calls with your customers directly from Chatwoot.'
    meeting_name: '%{agent_name} has started a meeting'
```

#### Dashboard Frontend: `app/javascript/dashboard/i18n/locale/en/integrations.json` (lines 132-138)
```json
"JITSI": {
  "CLICK_HERE_TO_JOIN": "Click here to join the call",
  "LEAVE_THE_ROOM": "Leave the room", 
  "START_VIDEO_CALL_HELP_TEXT": "Start a new video call with the customer using Jitsi Meet",
  "JOIN_ERROR": "Failed to join Jitsi call",
  "CREATE_ERROR": "There was an error creating a meeting link, please try again"
}
```

#### Widget Frontend: `app/javascript/widget/i18n/locale/en.json` (lines 124-127)
```json
"INTEGRATIONS": {
  "JITSI": {
    "CLICK_HERE_TO_JOIN": "Click here to join",
    "LEAVE_THE_ROOM": "Leave the call"
  }
}
```

## Message Structure & Data Flow

### Integration Message Format

**Database Schema**:
```ruby
Message.create!({
  account_id: conversation.account_id,
  inbox_id: conversation.inbox_id,
  message_type: :outgoing,           # Appears as agent-sent
  content_type: :integrations,       # Triggers integration rendering
  content: "John Doe has started a meeting",
  content_attributes: {
    type: 'jitsi',                   # Integration discriminator
    data: {
      room_name: 'chatwoot-7-abc123',
      created_by: 42,
      created_at: '2024-01-01T10:00:00Z'
    }
  },
  sender: agent
})
```

**Frontend Access Pattern**:
- **Dashboard**: `contentAttributes.value.data.room_name`
- **Widget**: `meetingData.room_name` (passed as prop)
- **Validation**: Both check for room_name presence to detect Jitsi vs Dyte

### Real-Time Synchronization

**Broadcast Mechanism**:
1. `JitsiService#create_a_meeting` calls `message.push_event_data`
2. WebSocket broadcasts message to all conversation participants
3. Dashboard and widget receive message simultaneously
4. Both render integration cards/bubbles for the same meeting

**Consistency Guarantees**:
- **Same room name**: Ensures agent and visitor join identical meeting
- **Same base URL**: Frontend and backend use consistent environment variables
- **Same message ID**: Enables participant addition and meeting management

## Error Handling & Edge Cases

### Backend Error Scenarios

#### Missing Conversation
```ruby
# Dashboard Controller
@conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
# Raises ActiveRecord::RecordNotFound if conversation doesn't exist

# Widget Controller  
unless @conversation
  return render json: { error: I18n.t('errors.jitsi.missing_conversation') }, status: :unprocessable_entity
end
```

#### Missing Agent (Widget Only)
```ruby
agent = @web_widget.inbox.account.users.first
unless agent
  return render json: { error: I18n.t('errors.jitsi.missing_agent') }, status: :unprocessable_entity
end
```

#### Invalid Message Type
```ruby
if @message.content_type != 'integrations' || @message.content_attributes['type'] != 'jitsi'
  return render json: { error: I18n.t('errors.jitsi.invalid_message_type') }, status: :unprocessable_entity
end
```

### Frontend Error Scenarios

#### Configuration Errors
- **Missing `VITE_JITSI_URL`**: `buildJitsiURL()` falls back to `'https://meet.jit.si'`
- **Invalid base URL**: Iframe fails to load, shows browser error page
- **Network issues**: API calls fail, trigger error alerts in UI

#### Integration Priority Conflicts
- **No integrations**: `VideoCallButton.vue` doesn't render (v-if guard)
- **Multiple integrations**: Priority logic ensures deterministic selection
- **Force flag**: `VITE_JITSI_FORCE_PRIMARY=true` overrides priority logic

#### Room Access Issues
- **Malformed room name**: Jitsi server may reject or create unexpected room
- **Concurrent access**: Multiple users can join same room (Jitsi handles this)
- **Room expiration**: Jitsi rooms persist until last participant leaves

## Extensibility & Future Work

### JWT Authentication Implementation

**Backend Changes Required**:
1. **Uncomment JWT code** in `lib/jitsi.rb#generate_jwt_token`
2. **Update service calls** to pass JWT tokens
3. **Add JWT gem** dependency to Gemfile

**Frontend Integration Points**:
```javascript
// Current stub implementation
export const getJitsiAuthToken = () => {
  return null; // TODO [JITSI-AUTH]
};

// Future implementation
export const getJitsiAuthToken = async () => {
  const response = await fetch('/api/v1/jitsi/auth_token');
  const { jwt_token } = await response.json();
  return jwt_token;
};
```

### Room Moderation Features

**Potential Enhancements**:
- **Agent as moderator**: Automatically grant moderation privileges to agents
- **Room passwords**: Generate secure room passwords for private meetings
- **Recording controls**: Start/stop meeting recordings from Chatwoot interface
- **Participant management**: Kick/mute participants from dashboard

### Advanced Configuration Options

**Hook Settings Extensions**:
```yaml
# Future apps.yml enhancement
jitsi:
  settings_json_schema:
    properties:
      app_id: { type: 'string' }
      secret_key: { type: 'string' }
      base_url: { type: 'string' }           # Custom Jitsi server
      enable_recording: { type: 'boolean' }   # Recording permissions
      default_moderator: { type: 'boolean' } # Agent moderation
      room_password: { type: 'boolean' }     # Password protection
```

### Testing Strategy

#### Backend Testing (RSpec)
```ruby
# spec/services/integrations/jitsi_service_spec.rb
describe Integrations::JitsiService do
  describe '#create_a_meeting' do
    it 'generates unique room names'
    it 'creates integration messages'
    it 'handles service errors gracefully'
  end
end

# spec/controllers/api/v1/accounts/integrations/jitsi_controller_spec.rb
describe Api::V1::Accounts::Integrations::JitsiController do
  describe 'POST #create_a_meeting' do
    it 'requires valid conversation'
    it 'authorizes inbox access'
    it 'returns meeting data'
  end
end
```

#### Frontend Testing (Jest + Vue Test Utils)
```javascript
// Dashboard component tests
describe('VideoCallButton.vue', () => {
  it('prioritizes Jitsi over Dyte when both available')
  it('calls JitsiAPI when Jitsi integration selected')
  it('shows appropriate error messages')
})

// Widget component tests  
describe('JitsiPanel.vue', () => {
  it('opens panel on jitsi:join-room event')
  it('builds correct iframe URL')
  it('handles fullscreen and PiP modes')
})
```

#### Integration Testing (Cypress)
```javascript
// e2e/integration/jitsi_video_calls.cy.js
describe('Jitsi Video Calls', () => {
  it('agent can start video call from dashboard')
  it('visitor can join call from widget')
  it('both participants see same meeting room')
  it('handles missing integration gracefully')
})
```

## Troubleshooting Common Issues

### 401 Unauthorized Errors

**Symptom**: API calls return 401 status
**Cause**: Calling Dyte endpoints instead of Jitsi endpoints
**Solution**: 
- Check `VideoCallButton.vue` integration detection logic
- Verify Jitsi integration is properly configured in admin UI
- Ensure `VITE_JITSI_FORCE_PRIMARY=true` if needed for testing

### Blank Video Iframe

**Symptom**: Iframe loads but shows empty/error page
**Causes & Solutions**:
- **Incorrect `VITE_JITSI_URL`**: Update environment variable to match your Jitsi server
- **CORS issues**: Configure Jitsi server to allow iframe embedding from Chatwoot domain
- **Network blocking**: Check firewall/proxy settings for Jitsi server access

### Room Name Conflicts

**Symptom**: Users join different/unexpected rooms
**Causes & Solutions**:
- **Malformed room names**: Check `generate_room_name` output format
- **Character encoding**: Ensure room names use URL-safe characters
- **Race conditions**: Multiple rapid calls may generate same SecureRandom.hex

### Integration Not Available

**Symptom**: Video call button doesn't appear
**Debugging Steps**:
1. Check admin integrations page for Jitsi entry
2. Verify `config/integration/apps.yml` includes Jitsi configuration
3. Check browser console for integration loading errors
4. Inspect `this.appIntegrations` in `VideoCallButton.vue`

### Widget Authentication Issues

**Symptom**: Widget API calls return authentication errors
**Causes**:
- **Missing `cw_conversation`**: Widget session not properly established
- **Invalid `X-Auth-Token`**: Pre-chat form didn't complete successfully
- **Session expiry**: Widget session timeout requires page refresh

**Solutions**:
- Ensure pre-chat form completion before video call attempts
- Check widget initialization parameters in browser Network tab
- Verify widget token validity in Rails logs

### Memory Leaks in Video Components

**Symptom**: Browser performance degrades after multiple video calls
**Prevention**:
- **PiP window cleanup**: `onBeforeUnmount` handlers close Picture-in-Picture windows
- **Event listener removal**: `emitter.off()` calls prevent orphaned listeners
- **Iframe destruction**: Setting `meetingUrl = ''` removes iframe from DOM

## Architecture Decision Records

### Why Separate Controllers for Dashboard vs Widget?

**Decision**: Maintain separate controller classes instead of shared controller
**Reasoning**:
- **Different authentication mechanisms**: User sessions vs widget tokens
- **Different authorization logic**: Account-based vs inbox-based permissions
- **Different error handling**: Agent-facing vs customer-facing messages
- **Future flexibility**: Enables different feature sets per interface

### Why Message-Based Integration Instead of Direct API?

**Decision**: Create integration messages rather than direct iframe embedding
**Reasoning**:
- **Conversation history**: Video calls become part of conversation timeline
- **Real-time sync**: Both dashboard and widget see same meeting information
- **Audit trail**: Meeting creation/participation tracked in message logs
- **Consistency**: Follows same pattern as Dyte and other integrations

### Why Priority-Based Integration Selection?

**Decision**: Smart detection logic instead of configuration setting
**Reasoning**:
- **User experience**: Automatically uses best available integration
- **Migration support**: Smooth transition from Dyte to Jitsi
- **Development flexibility**: `VITE_JITSI_FORCE_PRIMARY` for testing
- **Enterprise compatibility**: Maintains backward compatibility

## Security Considerations

### Current Security Model

**Room Access**:
- **No authentication**: Anyone with room URL can join
- **Predictable naming**: Room names follow deterministic pattern
- **Public Jitsi servers**: Default configuration uses public infrastructure

**Data Privacy**:
- **No external API calls**: Room creation happens locally
- **No user data transmission**: Jitsi server doesn't receive Chatwoot user info
- **Message encryption**: Integration messages use Chatwoot's standard encryption

### Future Security Enhancements

**JWT Authentication**:
- **Signed room access**: Prevent unauthorized room joining
- **User identification**: Pass agent/visitor names to Jitsi interface
- **Moderation controls**: Enforce agent moderation privileges
- **Time-based expiry**: Limit room access duration

**Room Security**:
- **Password protection**: Generate secure room passwords
- **Waiting rooms**: Require agent approval for visitor entry
- **Recording policies**: Control meeting recording permissions

## Performance Considerations

### Frontend Optimization

**Lazy Loading**:
- Video components only render when needed
- Iframe creation deferred until user join action
- Integration detection cached in computed properties

**Resource Management**:
- **PiP window tracking**: Prevents multiple PiP instances
- **Event listener cleanup**: Removes handlers on component destruction
- **Memory-conscious iframe handling**: Clears src to stop video streams

### Backend Efficiency

**Service Architecture**:
- **Stateless service**: No persistent connections or state
- **Minimal API calls**: No external HTTP requests required
- **Fast room generation**: SecureRandom.hex for immediate response

**Database Impact**:
- **Standard message creation**: Leverages existing message infrastructure
- **No additional tables**: Integrates with existing schema
- **Efficient queries**: Uses standard conversation/message relationships

---

*This documentation serves as the authoritative reference for maintaining and extending the Jitsi Meet integration in Chatwoot. For implementation details or troubleshooting specific issues, refer to the relevant file sections above.*