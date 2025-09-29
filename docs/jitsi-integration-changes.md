# Jitsi Meet Integration - Implementation Documentation

This document outlines the complete implementation of Jitsi Meet integration in Chatwoot, designed to work alongside the existing Dyte integration without conflicts.

## Overview

The Jitsi Meet integration allows agents to start video calls with customers using a self-hosted Jitsi Meet instance. This implementation uses iframe embedding for simplicity and includes placeholders for future JWT authentication.

## Backend Changes

### 1. Integration Configuration

**File: `config/integration/apps.yml`**
- Added Jitsi integration configuration with optional JWT settings
- Supports both simple iframe embedding and future JWT authentication

**File: `config/locales/en.yml`**
- Added integration_apps.jitsi localization entries
- Added error messages for Jitsi integration

### 2. Service Layer

**File: `app/services/integrations/jitsi_service.rb`**
- New service handling Jitsi meeting creation and participant management
- Generates URL-safe room names: `chatwoot-{conversation_id}-{random_hex}`
- Creates integration-type messages with proper content structure
- Supports future JWT token integration (currently commented out)

**File: `lib/jitsi.rb`**
- Jitsi client class for building meeting URLs
- Uses `JITSI_BASE_URL` environment variable (defaults to https://jitsi.xdec.io)
- Prepared for JWT token integration

### 3. API Endpoints

**File: `app/controllers/api/v1/accounts/integrations/jitsi_controller.rb`**
- Handles meeting creation and participant addition
- Validates message types for security
- Consistent with existing Dyte controller pattern

**File: `config/routes.rb`**
- Routes already configured for Jitsi endpoints

### 4. Environment Configuration

**File: `.env.example`**
- Added `JITSI_BASE_URL` for backend
- Added `VITE_JITSI_URL` for frontend
- Both default to https://jitsi.xdec.io

## Frontend Changes

### 1. Dashboard Components

**File: `app/javascript/dashboard/components-next/message/bubbles/Jitsi.vue`**
- Complete Jitsi meeting bubble component
- Iframe embedding with toolbar controls (Fullscreen, PiP, Pop-out, Leave)
- Uses shared IntegrationHelper functions
- Matches Dyte component UI/UX patterns

**File: `app/javascript/dashboard/components-next/message/Message.vue`**
- Added JitsiBubble import and routing
- Renders Jitsi bubble when `contentAttributes.type === 'jitsi'`

**File: `app/javascript/dashboard/components/widgets/VideoCallButton.vue`**
- Updated to support both Dyte and Jitsi integrations
- Automatically detects which integration is configured
- Uses appropriate API and localization based on integration type

### 2. Widget Components

**File: `app/javascript/widget/components/JitsiPanel.vue`**
- Widget-side Jitsi panel component
- Listens for `jitsi:join-room` events
- Same UI position and behavior as DytePanel

**File: `app/javascript/widget/components/template/IntegrationCard.vue`**
- Updated to support both Dyte and Jitsi integrations
- Detects integration type based on message data structure
- Emits appropriate events for each integration type

**File: `app/javascript/widget/views/Messages.vue`**
- Added JitsiPanel component alongside DytePanel

### 3. Shared Utilities

**File: `app/javascript/shared/helpers/IntegrationHelper.js`**
- Added `buildJitsiURL(roomName, jwtToken)` function
- Added `getJitsiAuthToken()` stub function
- Uses `VITE_JITSI_URL` environment variable

### 4. Localization

**File: `app/javascript/dashboard/i18n/locale/en/integrations.json`**
- Added INTEGRATION_SETTINGS.JITSI entries
- Consistent with Dyte localization structure

**File: `app/javascript/widget/i18n/locale/en.json`**
- Added INTEGRATIONS.JITSI widget localization

### 5. API Client

**File: `app/javascript/dashboard/api/integrations/jitsi.js`**
- Jitsi API client for dashboard
- Methods: `createAMeeting()`, `addParticipantToMeeting()`

## Testing

**File: `spec/services/integrations/jitsi_service_spec.rb`**
- Unit tests for Jitsi service
- Tests meeting creation and participant addition
- Mocks external dependencies

## End-to-End User Flow

### Agent Side (Dashboard)
1. Agent clicks "Start Video Call" button
2. System detects Jitsi integration is configured
3. POST request to `/api/v1/accounts/:id/integrations/jitsi/create_a_meeting`
4. Backend creates integration message with room_name
5. Message appears in conversation with Jitsi bubble
6. Agent clicks "Click here to join the call"
7. Iframe loads with Jitsi meeting room

### Customer Side (Widget)
1. Integration message appears in chat
2. Customer sees IntegrationCard with "Click here to join" button
3. Customer clicks button
4. JitsiPanel opens with iframe to same meeting room
5. Both parties are now in the same Jitsi room

## Configuration

### Environment Variables
```bash
# Backend - self-hosted Jitsi instance URL
JITSI_BASE_URL=https://jitsi.xdec.io

# Frontend - same URL for iframe embedding
VITE_JITSI_URL=https://jitsi.xdec.io
```

### Integration Setup
1. Navigate to Settings > Integrations
2. Find "Jitsi Meet" in the list
3. Click "Connect"
4. Optional: Enter App ID and Secret Key for JWT auth (future feature)
5. Save configuration

## Future Enhancements

### JWT Authentication (TODO)
- Uncomment JWT-related code in service and client
- Implement proper JWT token generation
- Add user context (name, avatar) to tokens
- Enable moderator permissions for agents

### Additional Features
- Recording support
- Screen sharing controls
- Meeting scheduling
- Custom branding

## Key Design Decisions

1. **Coexistence with Dyte**: Both integrations can be active simultaneously
2. **iframe Embedding**: Simple and reliable, avoids complex SDK integration
3. **Environment Configuration**: Flexible deployment with custom Jitsi instances
4. **URL-Safe Room Names**: Prevents issues with special characters
5. **Consistent UI/UX**: Matches existing Dyte integration patterns
6. **Security**: Validates message types and integration permissions

## Files Modified/Created

### New Files
- `app/services/integrations/jitsi_service.rb`
- `app/javascript/dashboard/api/integrations/jitsi.js`
- `app/javascript/dashboard/components-next/message/bubbles/Jitsi.vue`
- `app/javascript/widget/components/JitsiPanel.vue`
- `spec/services/integrations/jitsi_service_spec.rb`
- `public/dashboard/images/integrations/jitsi.png` (placeholder)
- `public/dashboard/images/integrations/jitsi-dark.png` (placeholder)

### Modified Files
- `config/integration/apps.yml`
- `config/locales/en.yml`
- `lib/jitsi.rb`
- `app/controllers/api/v1/accounts/integrations/jitsi_controller.rb`
- `.env.example`
- `app/javascript/dashboard/components-next/message/Message.vue`
- `app/javascript/dashboard/components/widgets/VideoCallButton.vue`
- `app/javascript/widget/components/template/IntegrationCard.vue`
- `app/javascript/widget/views/Messages.vue`
- `app/javascript/shared/helpers/IntegrationHelper.js`
- `app/javascript/dashboard/i18n/locale/en/integrations.json`
- `app/javascript/widget/i18n/locale/en.json`

### Removed Files
- `lib/integrations/jitsi/processor_service.rb` (replaced with app/services version)

## Testing Checklist

- [ ] Backend service creates meetings correctly
- [ ] Frontend bubble renders and controls work
- [ ] Widget panel opens and joins meetings
- [ ] Environment variables are properly configured
- [ ] Both Dyte and Jitsi can coexist
- [ ] Localization works correctly
- [ ] API endpoints respond correctly
- [ ] Error handling works as expected
- [ ] Room names are URL-safe and unique
- [ ] Iframe embedding works with target Jitsi instance