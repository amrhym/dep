# Dyte to Jitsi Migration Plan

## Table of Contents
1. [Current Dyte Integration Analysis](#1-current-dyte-integration-analysis)
2. [File-by-File Analysis](#2-file-by-file-analysis)
3. [Jitsi Integration Plan](#3-jitsi-integration-plan)
4. [Migration Strategy](#4-migration-strategy)
5. [Implementation Timeline](#5-implementation-timeline)

---

## 1. Current Dyte Integration Analysis

### Overview
The application currently integrates with Dyte's video calling platform to provide video/voice call functionality between agents and customers. The integration allows:
- **Agents** to start video meetings from the dashboard
- **Customers** to join meetings through the widget interface
- **Both parties** to participate in meetings via iframe-embedded video calls

### Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Agent UI      │    │   Customer UI    │    │   Dyte API      │
│  (Dashboard)    │    │    (Widget)      │    │                 │
├─────────────────┤    ├──────────────────┤    ├─────────────────┤
│ VideoCallButton │───▶│ IntegrationCard  │───▶│ Meeting API     │
│                 │    │                  │    │ Participants    │
│ DyteBubble      │    │ Dyte.vue         │    │ Auth Tokens     │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                ┌────────────────────────────────┐
                │     Backend Services           │
                ├────────────────────────────────┤
                │ Dyte::ProcessorService         │
                │ DyteController (Account)       │
                │ DyteController (Widget)        │
                │ Dyte Client Library            │
                └────────────────────────────────┘
```

### Key Dyte Features Utilized
1. **Meeting Creation**: Creating video meeting rooms with titles
2. **Participant Management**: Adding participants to meetings with authentication tokens
3. **Iframe Integration**: Embedding meetings via iframe with pre-configured settings
4. **Authentication**: Using organization ID and API key for backend authentication
5. **Preset Configuration**: Using `group_call_host` preset for permissions

### Integration Flow
1. **Meeting Creation**:
   - Agent clicks video call button in dashboard
   - Backend calls Dyte API to create meeting
   - Integration message is created in conversation
   
2. **Participant Joining**:
   - User (agent/customer) clicks "Join" on integration message
   - Backend calls Dyte API to add participant
   - Dyte returns authentication token
   - Frontend builds meeting URL with token
   - Meeting opens in fullscreen iframe

---

## 2. File-by-File Analysis

### Backend Files

#### `lib/dyte.rb`
**Purpose**: Core Dyte API client library
**Key Functions**:
- `initialize(organization_id, api_key)`: Authentication setup
- `create_a_meeting(title)`: Creates new meeting room
- `add_participant_to_meeting(meeting_id, client_id, name, avatar_url)`: Adds participant with auth token

**Dependencies**: HTTParty for API calls
**API Endpoints Used**:
- `POST /v2/meetings` - Meeting creation
- `POST /v2/meetings/{id}/participants` - Participant addition

#### `lib/integrations/dyte/processor_service.rb`
**Purpose**: Business logic layer for Dyte operations
**Key Functions**:
- `create_a_meeting(agent)`: Orchestrates meeting creation workflow
- `add_participant_to_meeting(meeting_id, user)`: Handles participant addition
- `create_a_dyte_integration_message(meeting, title, agent)`: Creates chat message

**Dependencies**: 
- `Dyte` client library
- Integration hooks system
- Message creation system

#### `app/controllers/api/v1/accounts/integrations/dyte_controller.rb`
**Purpose**: API endpoints for agent/admin operations
**Endpoints**:
- `POST /create_a_meeting`: Creates meeting for conversation
- `POST /add_participant_to_meeting`: Adds agent to existing meeting

**Authorization**: Requires agent access to conversation inbox

#### `app/controllers/api/v1/widget/integrations/dyte_controller.rb`
**Purpose**: API endpoints for customer widget operations

**will need to be replaced with JitsiController "yahya"**: make the user to be able to create a meeting from the widget as well

**Endpoints**:
- `POST /add_participant_to_meeting`: Adds customer to existing meeting

**Authorization**: Validates widget token and conversation access

### Frontend Files

#### `app/javascript/dashboard/api/integrations/dyte.js`
**Purpose**: Dashboard API client for Dyte operations
**Methods**:
- `createAMeeting(conversationId)`: Calls meeting creation endpoint
- `addParticipantToMeeting(messageId)`: Calls participant addition endpoint

#### `app/javascript/dashboard/components/widgets/VideoCallButton.vue`
**Purpose**: Video call button in conversation header

**will need to do in the jitsi button as well "Yahya"**: make the user to be able to create a meeting from the widget as well

**Functionality**:
- Shows button only when Dyte integration is enabled
- Triggers meeting creation
- Displays loading state during creation

#### `app/javascript/dashboard/components-next/message/bubbles/Dyte.vue`
**Purpose**: Message bubble for Dyte meetings in dashboard
**Features**:
- Shows meeting title and join button
- Handles participant addition for agents
- Displays fullscreen iframe when joined
- Provides leave meeting functionality

#### `app/javascript/widget/components/template/IntegrationCard.vue`
**Purpose**: Integration card for widget (customer interface)
**Features**:
- Customer-facing join meeting interface
- Handles participant addition for customers
- Displays fullscreen iframe for customer meetings

#### `app/javascript/shared/helpers/IntegrationHelper.js`
**Purpose**: Helper utilities for integration URL building
**Function**:
- `buildDyteURL(dyteAuthToken)`: Constructs Dyte meeting URL with auth token and settings

#### `app/javascript/widget/api/integration.js`
**Purpose**: Widget API client for Dyte operations
**Method**:
- `addParticipantToDyteMeeting(messageId)`: Widget-specific participant addition

### Configuration Files

#### `config/integration/apps.yml` (Dyte section)
**Purpose**: Integration configuration and settings schema
**Configuration**:
```yaml
dyte:
  id: dyte
  logo: dyte.png
  i18n_key: dyte
  action: /dyte
  hook_type: account
  allow_multiple_hooks: false
  settings_json_schema:
    type: 'object'
    properties:
      api_key: { type: 'string' }
      organization_id: { type: 'string' }
    required: ['api_key', 'organization_id']
```

#### Translation Files
**Backend**: `config/locales/en.yml`
```yaml
integration_apps:
  dyte:
    name: 'Dyte'
    short_description: 'Start video/voice calls with customers directly from Chatwoot.'
    description: 'Dyte is a product that integrates audio and video functionalities...'
    meeting_name: '%{agent_name} has started a meeting'
```

**Frontend**: Multiple locale files in `app/javascript/dashboard/i18n/locale/*/integrations.json`
```json
"DYTE": {
  "CLICK_HERE_TO_JOIN": "Click here to join",
  "LEAVE_THE_ROOM": "Leave the room",
  "START_VIDEO_CALL_HELP_TEXT": "Start a new video call with the customer",
  "JOIN_ERROR": "There was an error joining the call, please try again",
  "CREATE_ERROR": "There was an error creating a meeting link, please try again"
}
```

### Test Files
- `spec/lib/dyte_spec.rb`: Unit tests for Dyte client
- `spec/lib/integrations/dyte/processor_service_spec.rb`: Service layer tests
- `spec/controllers/api/v1/accounts/integrations/dyte_controller_spec.rb`: Controller tests (agent)
- `spec/controllers/api/v1/widget/integrations/dyte_controller_spec.rb`: Controller tests (widget)
- `spec/factories/integrations/hooks.rb`: Test factory for Dyte hooks

---

## 3. Jitsi Integration Plan

### Jitsi Meet Architecture Overview
Jitsi Meet provides open-source video conferencing that can be:
- **Self-hosted**: Complete control over infrastructure
- **Cloud-hosted**: Using Jitsi-as-a-Service providers
- **Hybrid**: Mix of self-hosted and cloud components

### Jitsi vs Dyte Feature Comparison

| Feature | Dyte Implementation | Jitsi Equivalent | Migration Complexity |
|---------|-------------------|------------------|---------------------|
| **Meeting Creation** | REST API call to create meeting | URL-based room creation | Low - No API call needed |
| **Participant Auth** | API call + auth token | JWT tokens or simple URL | Medium - JWT implementation |
| **Iframe Integration** | Direct iframe with auth token | Direct iframe with room URL | Low - URL format change |
| **Meeting URLs** | `app.dyte.io/v2/meeting?authToken=...` | `meet.jit.si/roomName` | Low - URL structure change |
| **Permissions** | Preset-based (`group_call_host`) | JWT claims or URL params | Medium - Different approach |
| **Avatar/Names** | API participant creation | JWT payload or URL params | Medium - Data passing method |
| **Backend API** | Required for all operations | Optional (JWT signing only) | High - Architecture change |

### Jitsi Integration Options

#### Option 1: Public Jitsi Meet (meet.jit.si)
**Pros**:
- No infrastructure setup required
- Immediate implementation
- No hosting costs

**Cons**:
- No authentication control
- Limited customization
- Privacy concerns for sensitive calls
- No usage analytics

#### Option 2: Self-Hosted Jitsi Meet
**Pros**:
- Complete control over data and privacy
- Full customization capabilities
- No per-meeting costs
- Custom branding possible

**Cons**:
- Infrastructure setup and maintenance
- Scaling complexity
- Higher initial setup effort

#### Option 3: Jitsi-as-a-Service (JaaS)
**Pros**:
- Managed infrastructure
- Enterprise features
- Authentication control
- Usage analytics

**Cons**:
- Subscription costs
- Still dependent on external service

### Recommended Approach: JWT-Based Authentication
For security and control, we recommend implementing JWT-based authentication:

```javascript
// JWT payload structure
{
  "iss": "your-app-id",
  "aud": "jitsi",
  "exp": timestamp,
  "room": "room-name",
  "sub": "meet.your-domain.com",
  "context": {
    "user": {
      "id": "user-id",
      "name": "User Name",
      "avatar": "https://avatar-url",
      "email": "user@email.com"
    },
    "features": {
      "livestreaming": false,
      "recording": false,
      "transcription": false
    }
  },
  "moderator": true // for agents, false for customers
}
```

---

## 4. Migration Strategy

### Phase 1: Backend Infrastructure Changes (Week 1-2)

#### 4.1 Replace Dyte Client Library
**File**: `lib/jitsi.rb` (new)
```ruby
class Jitsi
  include ActiveSupport::Configurable
  
  config_accessor :app_id, :secret_key, :base_url
  
  def initialize(app_id, secret_key, base_url = nil)
    @app_id = app_id
    @secret_key = secret_key
    @base_url = base_url || 'https://meet.jit.si'
  end
  
  def generate_jwt_token(room_name, user_id, user_name, avatar_url, is_moderator = false)
    payload = {
      iss: @app_id,
      aud: 'jitsi',
      exp: 24.hours.from_now.to_i,
      room: room_name,
      sub: @base_url.gsub('https://', ''),
      context: {
        user: {
          id: user_id.to_s,
          name: user_name,
          avatar: avatar_url
        },
        features: {
          livestreaming: false,
          recording: false,
          transcription: false
        }
      },
      moderator: is_moderator
    }
    
    JWT.encode(payload, @secret_key, 'HS256')
  end
  
  def build_meeting_url(room_name, jwt_token)
    "#{@base_url}/#{room_name}?jwt=#{jwt_token}"
  end
end
```

#### 4.2 Update Processor Service
**File**: `lib/integrations/jitsi/processor_service.rb` (new)
```ruby
class Integrations::Jitsi::ProcessorService
  pattr_initialize [:account!, :conversation!]

  def create_a_meeting(agent)
    room_name = generate_room_name
    title = I18n.t('integration_apps.jitsi.meeting_name', agent_name: agent.available_name)
    
    meeting_data = {
      room_name: room_name,
      created_by: agent.id,
      created_at: Time.current.iso8601
    }
    
    message = create_a_jitsi_integration_message(meeting_data, title, agent)
    message.push_event_data
    
    { success: true, data: meeting_data }
  rescue => e
    { error: { message: e.message }, error_code: 500 }
  end

  def add_participant_to_meeting(room_name, user, is_moderator = false)
    jwt_token = jitsi_client.generate_jwt_token(
      room_name,
      user.id,
      user.name,
      avatar_url(user),
      is_moderator
    )
    
    meeting_url = jitsi_client.build_meeting_url(room_name, jwt_token)
    
    { token: jwt_token, meeting_url: meeting_url }
  rescue => e
    { error: { message: e.message }, error_code: 500 }
  end

  private

  def generate_room_name
    "chatwoot-#{conversation.account_id}-#{conversation.id}-#{SecureRandom.hex(4)}"
  end

  def create_a_jitsi_integration_message(meeting_data, title, agent)
    @conversation.messages.create!(
      {
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        message_type: :outgoing,
        content_type: :integrations,
        content: title,
        content_attributes: {
          type: 'jitsi',
          data: meeting_data
        },
        sender: agent
      }
    )
  end

  def avatar_url(user)
    return user.avatar_url if user.avatar_url.present?
    "#{ENV.fetch('FRONTEND_URL', nil)}/integrations/slack/user.png"
  end

  def jitsi_hook
    @jitsi_hook ||= account.hooks.find_by!(app_id: 'jitsi')
  end

  def jitsi_client
    credentials = jitsi_hook.settings
    @jitsi_client ||= Jitsi.new(
      credentials['app_id'], 
      credentials['secret_key'],
      credentials['base_url']
    )
  end
end
```

#### 4.3 Update Controllers
**File**: `app/controllers/api/v1/accounts/integrations/jitsi_controller.rb` (new)
```ruby
class Api::V1::Accounts::Integrations::JitsiController < Api::V1::Accounts::BaseController
  before_action :fetch_conversation, only: [:create_a_meeting]
  before_action :fetch_message, only: [:add_participant_to_meeting]
  before_action :authorize_request

  def create_a_meeting
    render_response(jitsi_processor_service.create_a_meeting(Current.user))
  end

  def add_participant_to_meeting
    if @message.content_type != 'integrations' || @message.content_attributes['type'] != 'jitsi'
      return render json: {
        error: I18n.t('errors.jitsi.invalid_message_type')
      }, status: :unprocessable_entity
    end

    room_name = @message.content_attributes['data']['room_name']
    is_moderator = Current.user.is_a?(User) # agents are moderators
    
    render_response(
      jitsi_processor_service.add_participant_to_meeting(room_name, Current.user, is_moderator)
    )
  end

  private

  def authorize_request
    authorize @conversation.inbox, :show?
  end

  def render_response(response)
    render json: response, status: response[:error].blank? ? :ok : :unprocessable_entity
  end

  def jitsi_processor_service
    Integrations::Jitsi::ProcessorService.new(account: Current.account, conversation: @conversation)
  end

  def permitted_params
    params.permit(:conversation_id, :message_id)
  end

  def fetch_conversation
    @conversation = Current.account.conversations.find_by!(display_id: permitted_params[:conversation_id])
  end

  def fetch_message
    @message = Current.account.messages.find(permitted_params[:message_id])
    @conversation = @message.conversation
  end
end
```

### Phase 2: Frontend Migration (Week 2-3)

#### 4.4 Update Frontend API Clients
**File**: `app/javascript/dashboard/api/integrations/jitsi.js` (new)
```javascript
import ApiClient from '../ApiClient';

class JitsiAPI extends ApiClient {
  constructor() {
    super('integrations/jitsi', { accountScoped: true });
  }

  createAMeeting(conversationId) {
    return axios.post(`${this.url}/create_a_meeting`, {
      conversation_id: conversationId,
    });
  }

  addParticipantToMeeting(messageId) {
    return axios.post(`${this.url}/add_participant_to_meeting`, {
      message_id: messageId,
    });
  }
}

export default new JitsiAPI();
```

#### 4.5 Update Integration Helper
**File**: `app/javascript/shared/helpers/IntegrationHelper.js`
```javascript
// Remove Dyte function
// export const buildDyteURL = dyteAuthToken => {
//   return `${DYTE_MEETING_LINK}?authToken=${dyteAuthToken}&showSetupScreen=true&disableVideoBackground=true`;
// };

// Add Jitsi function
export const buildJitsiURL = (meetingUrl) => {
  return meetingUrl; // URL is already complete from backend
};

// Or if using direct construction:
export const buildJitsiURL = (baseUrl, roomName, jwtToken) => {
  const url = new URL(`${baseUrl}/${roomName}`);
  if (jwtToken) {
    url.searchParams.set('jwt', jwtToken);
  }
  // Add Jitsi-specific parameters
  url.searchParams.set('config.startWithAudioMuted', 'false');
  url.searchParams.set('config.startWithVideoMuted', 'false');
  url.searchParams.set('interfaceConfig.SHOW_JITSI_WATERMARK', 'false');
  url.searchParams.set('interfaceConfig.SHOW_WATERMARK_FOR_GUESTS', 'false');
  
  return url.toString();
};
```

#### 4.6 Update Video Call Button
**File**: `app/javascript/dashboard/components/widgets/VideoCallButton.vue`
```vue
<script>
import { mapGetters } from 'vuex';
import JitsiAPI from 'dashboard/api/integrations/jitsi'; // Changed from dyte
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    NextButton,
  },
  props: {
    conversationId: {
      type: Number,
      default: 0,
    },
  },
  data() {
    return { isLoading: false };
  },
  computed: {
    ...mapGetters({ appIntegrations: 'integrations/getAppIntegrations' }),
    isVideoIntegrationEnabled() {
      return this.appIntegrations.find(
        integration => integration.id === 'jitsi' && !!integration.hooks.length // Changed from 'dyte'
      );
    },
  },
  mounted() {
    if (!this.appIntegrations.length) {
      this.$store.dispatch('integrations/get');
    }
  },
  methods: {
    async onClick() {
      this.isLoading = true;
      try {
        await JitsiAPI.createAMeeting(this.conversationId); // Changed from DyteAPI
      } catch (error) {
        useAlert(this.$t('INTEGRATION_SETTINGS.JITSI.CREATE_ERROR')); // Changed from DYTE
      } finally {
        this.isLoading = false;
      }
    },
  },
};
</script>

<template>
  <NextButton
    v-if="isVideoIntegrationEnabled"
    v-tooltip.top-end="
      $t('INTEGRATION_SETTINGS.JITSI.START_VIDEO_CALL_HELP_TEXT')
    "
    icon="i-ph-video-camera"
    slate
    faded
    sm
    @click="onClick"
  />
</template>
```

#### 4.7 Create Jitsi Message Bubble
**File**: `app/javascript/dashboard/components-next/message/bubbles/Jitsi.vue` (new)
```vue
<script setup>
import { computed, ref } from 'vue';
import JitsiAPI from 'dashboard/api/integrations/jitsi';
import { buildJitsiURL } from 'shared/helpers/IntegrationHelper';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

import { useMessageContext } from '../provider.js';
import BaseAttachmentBubble from './BaseAttachment.vue';

const { content, sender, id, contentAttributes } = useMessageContext();

const { t } = useI18n();

const isLoading = ref(false);
const meetingUrl = ref('');

const joinTheCall = async () => {
  isLoading.value = true;
  try {
    const { data: { meeting_url } = {} } = await JitsiAPI.addParticipantToMeeting(
      id.value
    );
    meetingUrl.value = meeting_url;
  } catch (err) {
    useAlert(t('INTEGRATION_SETTINGS.JITSI.JOIN_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const leaveTheRoom = () => {
  meetingUrl.value = '';
};

const action = computed(() => ({
  label: t('INTEGRATION_SETTINGS.JITSI.CLICK_HERE_TO_JOIN'),
  onClick: joinTheCall,
}));
</script>

<template>
  <BaseAttachmentBubble
    icon="i-ph-video-camera-fill"
    icon-bg-color="bg-[#1D76ED]"
    sender-translation-key="CONVERSATION.SHARED_ATTACHMENT.MEETING"
    :action="action"
  >
    <div v-if="!sender" class="text-sm truncate text-n-slate-12">
      {{ content }}
    </div>
    <div v-if="meetingUrl" class="video-call--container">
      <iframe
        :src="meetingUrl"
        allow="camera;microphone;fullscreen;display-capture;picture-in-picture;clipboard-write;"
      />
      <button
        class="px-4 py-2 text-sm rounded-lg bg-n-solid-3 mt-3"
        @click="leaveTheRoom"
      >
        {{ $t('INTEGRATION_SETTINGS.JITSI.LEAVE_THE_ROOM') }}
      </button>
    </div>
    <div v-else>
      {{ '' }}
    </div>
  </BaseAttachmentBubble>
</template>

<style lang="scss">
.join-call-button {
  margin: 0.5rem 0;
}

.video-call--container {
  position: fixed;
  bottom: 0;
  right: 0;
  width: 100%;
  height: 100%;
  z-index: 1000;
  padding: 0.25rem;
  @apply bg-n-background;

  iframe {
    width: 100%;
    height: 100%;
    border: 0;
  }

  button {
    position: absolute;
    top: 0.25rem;
    right: 10rem;
  }
}
</style>
```

### Phase 3: Configuration and Deployment (Week 3-4)

#### 4.8 Update Integration Configuration
**File**: `config/integration/apps.yml`
```yaml
# Remove dyte section and add:
jitsi:
  id: jitsi
  logo: jitsi.png
  i18n_key: jitsi
  action: /jitsi
  hook_type: account
  allow_multiple_hooks: false
  settings_json_schema:
    {
      'type': 'object',
      'properties':
        {
          'app_id': { 'type': 'string' },
          'secret_key': { 'type': 'string' },
          'base_url': { 'type': 'string', 'default': 'https://meet.jit.si' },
        },
      'required': ['app_id', 'secret_key'],
      'additionalProperties': false,
    }
  settings_form_schema:
    [
      {
        'label': 'App ID',
        'type': 'text',
        'name': 'app_id',
        'validation': 'required',
        'help': 'Your Jitsi application identifier'
      },
      {
        'label': 'Secret Key',
        'type': 'password',
        'name': 'secret_key',
        'validation': 'required',
        'help': 'Secret key for JWT token generation'
      },
      {
        'label': 'Base URL',
        'type': 'text',
        'name': 'base_url',
        'placeholder': 'https://meet.jit.si',
        'help': 'Jitsi Meet server URL (leave empty for public Jitsi)'
      }
    ]
```

#### 4.9 Update Routes
**File**: `config/routes.rb`
```ruby
# Replace dyte routes with:
resource :jitsi, controller: 'jitsi', only: [] do
  collection do
    post :create_a_meeting
    post :add_participant_to_meeting
  end
end

# In widget section:
resource :jitsi, controller: 'jitsi', only: [] do
  collection do
    post :add_participant_to_meeting
  end
end
```

#### 4.10 Update Translations
**Backend** (`config/locales/en.yml`):
```yaml
integration_apps:
  jitsi:
    name: 'Jitsi Meet'
    short_description: 'Start video/voice calls with customers using open-source Jitsi Meet.'
    description: 'Jitsi Meet is an open-source video conferencing solution that provides secure, high-quality video calls. With this integration, your agents can start video/voice calls with your customers directly from Chatwoot.'
    meeting_name: '%{agent_name} has started a meeting'

errors:
  jitsi:
    invalid_message_type: 'Invalid message type. Action not permitted'
```

**Frontend** (all locale files in `app/javascript/dashboard/i18n/locale/*/integrations.json`):
```json
"JITSI": {
  "CLICK_HERE_TO_JOIN": "Click here to join",
  "LEAVE_THE_ROOM": "Leave the meeting",
  "START_VIDEO_CALL_HELP_TEXT": "Start a new video call with the customer",
  "JOIN_ERROR": "There was an error joining the call, please try again",
  "CREATE_ERROR": "There was an error creating a meeting link, please try again"
}
```

### Phase 4: Testing and Migration Script (Week 4)

#### 4.11 Data Migration Script
**File**: `db/migrate/add_jitsi_integration_migration.rb`
```ruby
class AddJitsiIntegrationMigration < ActiveRecord::Migration[7.0]
  def up
    # Update existing Dyte integration messages to Jitsi format
    Message.where(content_type: 'integrations')
           .where("content_attributes->>'type' = ?", 'dyte')
           .find_each do |message|
      
      old_data = message.content_attributes['data']
      new_data = {
        'type' => 'jitsi',
        'data' => {
          'room_name' => "migrated-dyte-#{old_data['meeting_id']}",
          'migrated_from_dyte' => true,
          'original_meeting_id' => old_data['meeting_id']
        }
      }
      
      message.update!(content_attributes: new_data)
    end
    
    # Update hook configurations from Dyte to Jitsi
    Integrations::Hook.where(app_id: 'dyte').find_each do |hook|
      old_settings = hook.settings
      new_settings = {
        'app_id' => "chatwoot-#{hook.account_id}",
        'secret_key' => SecureRandom.hex(32), # Generate new secret
        'base_url' => 'https://meet.jit.si' # Default to public Jitsi
      }
      
      hook.update!(
        app_id: 'jitsi',
        settings: new_settings
      )
      
      # Store old settings for reference
      hook.update_column(:reference, old_settings.to_json)
    end
  end
  
  def down
    # Revert changes if needed
    Message.where(content_type: 'integrations')
           .where("content_attributes->>'type' = ?", 'jitsi')
           .where("content_attributes->'data'->>'migrated_from_dyte' = ?", 'true')
           .find_each do |message|
      
      new_data = message.content_attributes['data']
      old_data = {
        'type' => 'dyte',
        'data' => {
          'meeting_id' => new_data['original_meeting_id']
        }
      }
      
      message.update!(content_attributes: old_data)
    end
    
    Integrations::Hook.where(app_id: 'jitsi').find_each do |hook|
      if hook.reference.present?
        old_settings = JSON.parse(hook.reference)
        hook.update!(
          app_id: 'dyte',
          settings: old_settings,
          reference: nil
        )
      end
    end
  end
end
```

---

## 5. Implementation Timeline

### Week 1: Backend Foundation
**Days 1-2**: 
- Create Jitsi client library (`lib/jitsi.rb`)
- Implement JWT token generation
- Add JWT gem to Gemfile

**Days 3-4**:
- Create Jitsi processor service
- Update integration configuration
- Add new routes

**Days 5-7**:
- Implement Jitsi controllers
- Write comprehensive unit tests
- Update backend translations

**Deliverables**:
- ✅ Working backend API for Jitsi
- ✅ JWT token generation
- ✅ Unit tests passing
- ✅ Integration configuration complete

### Week 2: Frontend Migration
**Days 1-3**:
- Create Jitsi API clients
- Update integration helpers
- Create new Jitsi message bubble component

**Days 4-5**:
- Update video call button component
- Modify widget integration card
- Update message provider and routing

**Days 6-7**:
- Update all frontend translations
- Implement error handling
- Create frontend tests

**Deliverables**:
- ✅ Complete frontend Jitsi integration
- ✅ Updated UI components
- ✅ Frontend tests passing
- ✅ Translations updated

### Week 3: Integration and Testing
**Days 1-2**:
- Integration testing between frontend and backend
- End-to-end testing of video call flow
- Cross-browser compatibility testing

**Days 3-4**:
- Performance testing
- Security review of JWT implementation
- UI/UX testing and refinement

**Days 5-7**:
- Create data migration script
- Test migration script with sample data
- Documentation and deployment preparation

**Deliverables**:
- ✅ Fully tested Jitsi integration
- ✅ Migration script ready
- ✅ Security review complete
- ✅ Documentation updated

### Week 4: Deployment and Migration
**Days 1-2**:
- Deploy backend changes to staging
- Run migration script on staging data
- Validate migrated meetings work correctly

**Days 3-4**:
- Deploy to production during maintenance window
- Run production migration script
- Monitor system health and error logs

**Days 5-7**:
- Remove Dyte-related code and dependencies
- Update admin documentation
- Create user migration guide
- Post-deployment monitoring

**Deliverables**:
- ✅ Production deployment complete
- ✅ All existing meetings migrated
- ✅ Dyte integration fully removed
- ✅ User documentation updated

---

## Migration Challenges and Solutions

### 1. Authentication Model Differences
**Challenge**: Dyte uses API-based participant addition with auth tokens, while Jitsi uses JWT-based authentication.

**Solution**: 
- Implement JWT signing in backend
- Pre-generate meeting URLs with embedded JWT tokens
- Maintain security through proper JWT expiration and claims

### 2. Meeting Persistence
**Challenge**: Dyte meetings are persistent API objects, while Jitsi rooms are ephemeral.

**Solution**:
- Generate unique room names for each meeting
- Store room metadata in message content_attributes
- Implement room name generation that prevents conflicts

### 3. Participant Management
**Challenge**: Dyte has explicit participant addition API, while Jitsi relies on JWT claims.

**Solution**:
- Generate individual JWT tokens for each participant
- Include user metadata (name, avatar) in JWT claims
- Use moderator flag in JWT to distinguish agents from customers

### 4. Iframe Integration Changes
**Challenge**: Different URL structures and authentication methods.

**Solution**:
- Update iframe src URLs to use Jitsi format
- Add Jitsi-specific configuration parameters
- Maintain same fullscreen behavior

### 5. Existing Meeting Migration
**Challenge**: Existing Dyte meetings in chat history need to work or be clearly marked as deprecated.

**Solution**:
- Create migration script to convert message format
- Add "migrated" flags to distinguish converted meetings
- Consider showing deprecated state for very old meetings

### 6. Configuration Migration
**Challenge**: Admin settings need to be converted from Dyte to Jitsi format.

**Solution**:
- Automated migration of integration hooks
- Clear admin communication about new configuration requirements
- Backup old settings for rollback capability

---

## Security Considerations

### JWT Token Security
- Use strong secret keys (minimum 256 bits)
- Implement proper token expiration (recommended: 24 hours)
- Include audience and issuer claims for validation
- Store secret keys securely (environment variables)

### Meeting Room Security
- Generate cryptographically secure room names
- Include account/conversation context in room names
- Implement room name collision prevention
- Consider adding room expiration

### API Security
- Maintain existing authorization checks
- Validate message types before processing
- Sanitize user inputs in JWT claims
- Implement rate limiting on meeting creation

---

## Testing Strategy

### Unit Tests
- Jitsi client library functions
- JWT token generation and validation
- Processor service methods
- Controller endpoint functionality

### Integration Tests
- End-to-end meeting creation flow
- Participant addition for agents and customers
- Message creation and updating
- API authentication and authorization

### Security Tests
- JWT token validation
- Authorization boundary testing
- Input sanitization testing
- Rate limiting verification

### UI Tests
- Component rendering with Jitsi data
- Meeting join/leave functionality
- Error state handling
- Cross-browser compatibility

---

## Rollback Plan

### Emergency Rollback (< 1 hour)
1. Revert application deployment to previous version
2. Restore database from pre-migration backup
3. Update DNS/load balancer to previous version
4. Communicate status to users

### Partial Rollback (Migration Issues)
1. Run migration script in reverse mode
2. Restore Dyte integration configuration
3. Update feature flags to disable Jitsi
4. Investigate and fix migration issues

### Data Recovery
1. Database backups before migration
2. Export of Dyte integration settings
3. Message content backup for verification
4. Integration hook configuration backup

---

## Post-Migration Checklist

### Immediate (Day 1)
- [ ] All existing meetings accessible
- [ ] New meeting creation working
- [ ] Agent and customer join flows functional
- [ ] Error monitoring active
- [ ] Performance metrics baseline established

### Short-term (Week 1)
- [ ] User feedback collected and addressed
- [ ] Performance optimization if needed
- [ ] Documentation updated
- [ ] Admin training completed
- [ ] Support team briefed on changes

### Long-term (Month 1)
- [ ] Dyte dependencies removed from codebase
- [ ] Security audit of JWT implementation
- [ ] Performance analysis and optimization
- [ ] User adoption metrics reviewed
- [ ] Cost analysis (if using hosted Jitsi)

---

## Conclusion

This migration plan provides a comprehensive pathway from Dyte to Jitsi Meet integration. The phased approach minimizes risk while ensuring feature parity and improved security through JWT-based authentication. The implementation timeline allows for thorough testing and validation at each stage, with clear rollback procedures to ensure business continuity.

Key benefits of the migration:
- **Reduced vendor lock-in**: Open-source solution with hosting flexibility
- **Enhanced security**: JWT-based authentication with full control
- **Cost optimization**: Potential cost savings with self-hosted or alternative providers
- **Customization capabilities**: Full control over meeting experience and branding
- **Privacy control**: Option for on-premises deployment for sensitive use cases

The migration maintains backward compatibility during the transition period and provides clear upgrade paths for existing integrations.