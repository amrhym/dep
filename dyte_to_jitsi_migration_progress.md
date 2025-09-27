# Dyte to Jitsi Migration - Current Progress Report

## Overview

This document analyzes the current state of the Dyte to Jitsi migration on the `video` branch compared to the planned migration in `dyte_to_jitsi_migration.md`. The branch shows a **partial implementation** of Jitsi integration alongside **enhanced Dyte features**.

---

## Current Branch Status: `video` (merged from `feature/jitsi-integration`)

### Branch Context
- **Current Branch**: `video`
- **Source**: Merged from `feature/jitsi-integration` 
- **Commit**: `95407b6ea Merge branch 'feature/jitsi-integration' into video`
- **Status**: **Dual Integration** - Both Dyte and Jitsi coexist

---

## 🟡 Backend Changes - What's Actually Implemented

### ✅ **Jitsi Infrastructure - PARTIALLY IMPLEMENTED**

#### 1. Jitsi Client Library (`lib/jitsi.rb`)
**Status**: 🟡 **Basic Implementation - Missing Key Features**
```ruby
class Jitsi
  def initialize(app_id, secret_key)
    @app_id = app_id
    @secret_key = secret_key
    @base_url = ENV.fetch('JITSI_BASE_URL', nil)
  end

  def build_meeting_url(room_name)
    "#{@base_url}/#{room_name}"
  end
end
```

**❌ Missing from Plan**:
- JWT token generation (commented out)
- User authentication
- Moderator permissions
- Security features

#### 2. Jitsi Processor Service (`lib/integrations/jitsi/processor_service.rb`)
**Status**: 🟡 **Basic Implementation**
```ruby
def add_participant_to_meeting(room_name)
  meeting_url = jitsi_client.build_meeting_url(room_name)
  { meeting_url: meeting_url }
end
```

**❌ Missing from Plan**:
- JWT token generation for participants
- User metadata handling
- Moderator role assignment
- Security validation

#### 3. Jitsi Controller (`app/controllers/api/v1/accounts/integrations/jitsi_controller.rb`)
**Status**: ✅ **Implemented** - Matches planned structure

### ✅ **Enhanced Dyte Features - NEW ADDITIONS**

#### 1. Scheduled Video Calls
**Status**: ✅ **Fully Implemented** - Not in original plan
- `ScheduledVideoCall` model with statuses
- Scheduling endpoints in Dyte controller
- Email/SMS/WhatsApp notifications
- Reminder job system

#### 2. Enhanced Video Experience
**Status**: ✅ **Implemented** - Enhanced from original
- Picture-in-Picture (PiP) support
- Fullscreen mode
- Pop-out windows
- Inline chat + video experience

#### 3. Notification System
**Status**: ✅ **New Feature**
- `VideoCallMailer` for email notifications
- `ScheduledVideoCallNotifier` service
- Multiple notification channels (Email, SMS, WhatsApp)

---

## 🟡 Frontend Changes - What's Actually Implemented

### ❌ **Jitsi Frontend - NOT IMPLEMENTED**

**Missing Components**:
- No Jitsi API client (`app/javascript/dashboard/api/integrations/jitsi.js`)
- No Jitsi message bubble component
- No Jitsi integration in widget
- No Jitsi URL building helpers

### ✅ **Enhanced Dyte Frontend - IMPROVED**

#### 1. Enhanced Dashboard Components
**File**: `app/javascript/dashboard/components-next/message/bubbles/Dyte.vue`
**New Features**:
```javascript
// Picture-in-Picture support
const requestPiP = async () => {
  pipWindow = await window.documentPictureInPicture.requestWindow({ width: 480, height: 270 });
  // ... iframe setup
};

// Fullscreen support
const enterFullscreen = async () => {
  if (panelRef.value && panelRef.value.requestFullscreen) {
    await panelRef.value.requestFullscreen();
  }
};

// Pop-out window
const popout = () => {
  const features = 'popup=yes,width=900,height=600,menubar=no,toolbar=no,location=no,status=no';
  window.open(meetingLink.value, 'dyte_popout', features);
};
```

#### 2. New Widget Components
**Files Added**:
- `DytePanel.vue` - Comprehensive video panel with PiP/fullscreen
- `ScheduleVideoCallForm.vue` - Scheduling interface

#### 3. Enhanced Integration Card
**File**: `app/javascript/widget/components/template/IntegrationCard.vue`
- Auto-join functionality
- Enhanced UI/UX
- Better error handling

---

## 📊 Migration Plan vs Reality Comparison

| Component | Planned Status | Actual Status | Gap |
|-----------|---------------|---------------|-----|
| **Backend Jitsi Client** | ✅ Complete with JWT | 🟡 Basic without JWT | High |
| **Backend Jitsi Service** | ✅ Full participant mgmt | 🟡 Basic URL generation | High |
| **Backend Jitsi Controller** | ✅ Complete | ✅ Complete | None |
| **Frontend Jitsi API** | ✅ Complete | ❌ Not implemented | Critical |
| **Frontend Jitsi Components** | ✅ Complete | ❌ Not implemented | Critical |
| **Frontend Jitsi Integration** | ✅ Complete | ❌ Not implemented | Critical |
| **Configuration Migration** | ✅ Complete | ❌ Not implemented | High |
| **Data Migration Scripts** | ✅ Complete | ❌ Not implemented | High |
| **Dyte Removal** | ✅ Complete removal | ❌ Still fully present | Critical |

---

## 🔍 Configuration Status

### ✅ **What's Configured**

#### Backend Routes
```ruby
# config/routes.rb
resource :jitsi, controller: 'jitsi', only: [] do
  collection do
    post :create_a_meeting
    post :add_participant_to_meeting
  end
end
```

#### Translations
```yaml
# config/locales/en.yml
jitsi:
  name: 'Jitsi Meet'
  short_description: 'Start video/voice calls with customers using open-source Jitsi Meet.'
  description: 'Jitsi Meet is an open-source video conferencing solution...'
```

### ❌ **What's Missing**

#### Integration Configuration
- No `jitsi:` section in `config/integration/apps.yml`
- No settings schema for Jitsi configuration
- No form schema for admin setup

#### Frontend Configuration
- No Jitsi integration in store/modules
- No Jitsi components registered
- No routing for Jitsi messages

---

## 🚧 Current Implementation Approach

### **Dual Integration Strategy**
The current implementation maintains **both Dyte and Jitsi** simultaneously:

1. **Dyte**: Enhanced with scheduling, notifications, and better UX
2. **Jitsi**: Basic backend infrastructure only

### **Missing Migration Path**
- No migration from Dyte to Jitsi
- No unified integration selection
- No removal of Dyte dependencies

---

## 🎯 What Still Needs to Be Done

### **Phase 1: Complete Jitsi Backend (High Priority)**

#### 1. Implement JWT Authentication
```ruby
# lib/jitsi.rb - ADD
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
      }
    },
    moderator: is_moderator
  }
  JWT.encode(payload, @secret_key, 'HS256')
end
```

#### 2. Complete Processor Service
```ruby
# lib/integrations/jitsi/processor_service.rb - MODIFY
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
end
```

#### 3. Add Integration Configuration
```yaml
# config/integration/apps.yml - ADD
jitsi:
  id: jitsi
  logo: jitsi.png
  i18n_key: jitsi
  action: /jitsi
  hook_type: account
  allow_multiple_hooks: false
  settings_json_schema:
    type: 'object'
    properties:
      app_id: { type: 'string' }
      secret_key: { type: 'string' }
      base_url: { type: 'string', default: 'https://meet.jit.si' }
    required: ['app_id', 'secret_key']
```

### **Phase 2: Implement Jitsi Frontend (Critical Priority)**

#### 1. Create Jitsi API Client
**File**: `app/javascript/dashboard/api/integrations/jitsi.js` - **CREATE**
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

#### 2. Create Jitsi Message Bubble
**File**: `app/javascript/dashboard/components-next/message/bubbles/Jitsi.vue` - **CREATE**
```vue
<script setup>
import { computed, ref } from 'vue';
import JitsiAPI from 'dashboard/api/integrations/jitsi';
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
    const { data: { meeting_url } = {} } = await JitsiAPI.addParticipantToMeeting(id.value);
    meetingUrl.value = meeting_url;
  } catch (err) {
    useAlert(t('INTEGRATION_SETTINGS.JITSI.JOIN_ERROR'));
  } finally {
    isLoading.value = false;
  }
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
    <div v-if="meetingUrl" class="video-call--container">
      <iframe
        :src="meetingUrl"
        allow="camera;microphone;fullscreen;display-capture;picture-in-picture;clipboard-write;"
      />
      <button class="px-4 py-2 text-sm rounded-lg bg-n-solid-3 mt-3" @click="() => meetingUrl = ''">
        {{ $t('INTEGRATION_SETTINGS.JITSI.LEAVE_THE_ROOM') }}
      </button>
    </div>
  </BaseAttachmentBubble>
</template>
```

#### 3. Update Message Provider
**File**: `app/javascript/dashboard/components-next/message/Message.vue` - **MODIFY**
```javascript
// Add Jitsi bubble import
import JitsiBubble from './bubbles/Jitsi.vue';

// Add to components
components: {
  // ... existing
  JitsiBubble,
}

// Update bubble selection logic
const bubbleComponent = computed(() => {
  // ... existing logic
  if (contentType.value === 'integrations') {
    const integrationType = contentAttributes.value?.type;
    if (integrationType === 'jitsi') return 'JitsiBubble';
    if (integrationType === 'dyte') return 'DyteBubble';
  }
  // ... rest of logic
});
```

#### 4. Update Video Call Button
**File**: `app/javascript/dashboard/components/widgets/VideoCallButton.vue` - **MODIFY**
```javascript
// Add integration detection for both Dyte and Jitsi
computed: {
  isVideoIntegrationEnabled() {
    return this.appIntegrations.find(
      integration => 
        (integration.id === 'dyte' || integration.id === 'jitsi') && 
        !!integration.hooks.length
    );
  },
  
  // Add preferred integration selection
  preferredIntegration() {
    // Prefer Jitsi if both are available
    return this.appIntegrations.find(i => i.id === 'jitsi' && !!i.hooks.length) ||
           this.appIntegrations.find(i => i.id === 'dyte' && !!i.hooks.length);
  }
},

methods: {
  async onClick() {
    this.isLoading = true;
    try {
      // Use preferred integration
      if (this.preferredIntegration.id === 'jitsi') {
        await JitsiAPI.createAMeeting(this.conversationId);
      } else {
        await DyteAPI.createAMeeting(this.conversationId);
      }
    } catch (error) {
      const errorKey = this.preferredIntegration.id === 'jitsi' ? 
        'INTEGRATION_SETTINGS.JITSI.CREATE_ERROR' : 
        'INTEGRATION_SETTINGS.DYTE.CREATE_ERROR';
      useAlert(this.$t(errorKey));
    } finally {
      this.isLoading = false;
    }
  },
}
```

### **Phase 3: Migration and Transition (Medium Priority)**

#### 1. Create Migration Script
**File**: `db/migrate/add_jitsi_migration.rb` - **CREATE**
```ruby
class AddJitsiMigration < ActiveRecord::Migration[7.0]
  def up
    # Convert Dyte integration messages to Jitsi format
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
  end
end
```

#### 2. Admin Migration Interface
**File**: `app/controllers/api/v1/accounts/integrations/migration_controller.rb` - **CREATE**
```ruby
class Api::V1::Accounts::Integrations::MigrationController < Api::V1::Accounts::BaseController
  def migrate_dyte_to_jitsi
    # Check if Jitsi is configured
    jitsi_hook = Current.account.hooks.find_by(app_id: 'jitsi')
    unless jitsi_hook
      return render json: { error: 'Jitsi integration not configured' }, status: :unprocessable_entity
    end
    
    # Perform migration
    migration_count = migrate_messages
    
    render json: { 
      success: true, 
      migrated_messages: migration_count,
      message: "Successfully migrated #{migration_count} messages from Dyte to Jitsi"
    }
  end
  
  private
  
  def migrate_messages
    # Implementation of message migration logic
  end
end
```

### **Phase 4: Complete Removal of Dyte (Low Priority)**

#### 1. Remove Dyte Dependencies
- Remove `lib/dyte.rb`
- Remove `lib/integrations/dyte/processor_service.rb`
- Remove Dyte controllers
- Remove Dyte frontend components

#### 2. Update References
- Remove Dyte from integration apps configuration
- Update all translations
- Remove Dyte API clients
- Clean up routes

---

## 🔧 How to Continue the Migration

### **Immediate Next Steps (This Week)**

1. **Complete JWT Implementation**
   ```bash
   # Add JWT gem to Gemfile
   gem 'jwt'
   
   # Implement JWT token generation in lib/jitsi.rb
   # Update processor service to use JWT tokens
   ```

2. **Add Jitsi Integration Configuration**
   ```bash
   # Update config/integration/apps.yml
   # Add Jitsi settings schema
   # Test admin configuration interface
   ```

3. **Create Basic Jitsi Frontend**
   ```bash
   # Create Jitsi API client
   # Create Jitsi message bubble component
   # Update message routing
   ```

### **Week 2-3: Full Frontend Implementation**

4. **Complete Frontend Migration**
   - Implement all planned Jitsi components
   - Add widget integration support
   - Update video call button logic
   - Add error handling and loading states

5. **Testing and Validation**
   - Test end-to-end Jitsi flow
   - Validate JWT token security
   - Cross-browser compatibility
   - Performance testing

### **Week 4: Migration and Cleanup**

6. **Data Migration**
   - Create and test migration scripts
   - Plan migration window
   - Backup existing data
   - Execute migration

7. **Dyte Removal**
   - Remove Dyte components gradually
   - Update documentation
   - Clean up unused code
   - Final testing

---

## 🎯 Key Decisions Needed

### **1. Integration Strategy**
**Current**: Dual integration (both Dyte and Jitsi)
**Options**:
- A) Complete migration to Jitsi only
- B) Keep both integrations as options
- C) Gradual migration with feature flags

**Recommendation**: Option A - Complete migration for simplicity and reduced maintenance

### **2. Scheduled Calls Feature**
**Current**: Implemented for Dyte only
**Decision**: Migrate scheduling to Jitsi or maintain hybrid approach?

**Recommendation**: Implement scheduling for Jitsi to match current Dyte features

### **3. Enhanced Video Features**
**Current**: PiP, fullscreen, popout implemented for Dyte
**Decision**: Replicate in Jitsi or enhance further?

**Recommendation**: Replicate all enhanced features in Jitsi implementation

---

## 📈 Success Metrics

### **Technical Metrics**
- [ ] JWT authentication working
- [ ] All frontend components functional
- [ ] End-to-end video calls working
- [ ] Migration scripts tested
- [ ] Performance baseline maintained

### **Business Metrics**
- [ ] Zero downtime during migration
- [ ] All existing meetings accessible
- [ ] Feature parity with current Dyte implementation
- [ ] Enhanced security through JWT
- [ ] Reduced vendor dependency

---

## 🚨 Risk Assessment

### **High Risk**
- **Incomplete JWT Implementation**: Security vulnerability
- **Missing Frontend**: Broken user experience
- **No Migration Path**: Data loss potential

### **Medium Risk**
- **Dual Integration Confusion**: User experience issues
- **Performance Impact**: Multiple video systems
- **Configuration Complexity**: Admin confusion

### **Low Risk**
- **Feature Parity**: Temporary feature gaps
- **Documentation**: Learning curve for admins

---

## 📝 Conclusion

The current `video` branch represents a **partial implementation** of the planned Dyte to Jitsi migration. While the **backend Jitsi infrastructure** exists, it's missing critical security features (JWT) and the **frontend implementation is completely absent**.

**Key Findings**:
1. ✅ **Enhanced Dyte**: Significant improvements with scheduling and better UX
2. 🟡 **Basic Jitsi Backend**: Infrastructure exists but incomplete
3. ❌ **No Jitsi Frontend**: Critical gap preventing full migration
4. ❌ **No Migration Path**: No way to transition from Dyte to Jitsi

**Recommended Approach**:
1. **Complete Jitsi JWT implementation** (security critical)
2. **Build full Jitsi frontend** (user experience critical)
3. **Implement migration scripts** (data integrity critical)
4. **Plan removal of Dyte** (maintenance reduction)

The migration is **approximately 30% complete** with most of the foundational work done but critical user-facing components missing.