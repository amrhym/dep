<script setup>
import { computed, ref, onBeforeUnmount } from 'vue';
import { buildJitsiURL, getJitsiAuthToken } from 'shared/helpers/IntegrationHelper';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

import { useMessageContext } from '../provider.js';
import BaseAttachmentBubble from './BaseAttachment.vue';

const { content, sender, contentAttributes } = useMessageContext();

const { t } = useI18n();

const isLoading = ref(false);
const meetingUrl = ref('');
const isFullscreen = ref(false);

const roomName = computed(() => contentAttributes?.value?.data?.room_name || contentAttributes?.value?.data?.roomName);

const panelRef = ref(null);

// Listen for fullscreen changes
document.addEventListener('fullscreenchange', () => {
  isFullscreen.value = !!document.fullscreenElement;
});

const enterFullscreen = async () => {
  try {
    if (isFullscreen.value) {
      // Exit fullscreen
      if (document.exitFullscreen) {
        await document.exitFullscreen();
      }
    } else {
      // Enter fullscreen
      if (panelRef.value && panelRef.value.requestFullscreen) {
        await panelRef.value.requestFullscreen();
      }
    }
  } catch (e) { }
};

const joinTheCall = async () => {
  isLoading.value = true;
  try {
    const jwt = getJitsiAuthToken(); // TODO [JITSI-AUTH]
    if (!roomName.value) {
      throw new Error('Missing Jitsi room name');
    }
    meetingUrl.value = buildJitsiURL(roomName.value, jwt);
  } catch (err) {
    useAlert(t('INTEGRATION_SETTINGS.JITSI.JOIN_ERROR', 'Failed to join Jitsi call'));
  } finally {
    isLoading.value = false;
  }
};

const leaveTheRoom = () => {
  meetingUrl.value = '';
};

onBeforeUnmount(() => {
  // Exit fullscreen if active
  if (isFullscreen.value && document.exitFullscreen) {
    try { document.exitFullscreen(); } catch (e) { }
  }
});

const action = computed(() => ({
  label: t('INTEGRATION_SETTINGS.JITSI.CLICK_HERE_TO_JOIN', 'Click here to join the call'),
  onClick: joinTheCall,
}));
</script>

<template>
  <BaseAttachmentBubble icon="i-ph-video-camera-fill" icon-bg-color="bg-[#2781F6]"
    sender-translation-key="CONVERSATION.SHARED_ATTACHMENT.MEETING" :action="action">
    <div v-if="!sender" class="text-sm truncate text-n-slate-12">
      {{ content }}
    </div>
    <div v-if="meetingUrl" class="video-call--container" ref="panelRef">
      <div class="toolbar">
        <button class="btn" @click="enterFullscreen">
          {{ isFullscreen ? '⛶ Exit Fullscreen' : '⛶ Fullscreen' }}
        </button>
        <button class="btn leave" @click="leaveTheRoom">
          <!-- {{ $t('INTEGRATION_SETTINGS.JITSI.LEAVE_THE_ROOM', 'Leave the room') }} -->
          X
        </button>
      </div>
      <iframe :src="meetingUrl"
        allow="camera;microphone;fullscreen;display-capture;picture-in-picture;clipboard-write;" />
    </div>
    <div v-else>
      {{ '' }}
    </div>
  </BaseAttachmentBubble>
</template>

<style lang="scss">
.video-call--container {
  position: relative;
  width: 100%;
  height: 420px;
  z-index: 1;
  padding: 0.25rem;
  @apply bg-n-background;

  .toolbar {
    position: absolute;
    top: 0.25rem;
    right: 0.25rem;
    z-index: 10;
    display: flex;
    flex-wrap: wrap;
    flex-direction: row;

    gap: 8px;
    margin-bottom: 6px;
  }

  .toolbar .btn {
    padding: 4px 8px;
    font-size: 12px;
    border-radius: 6px;
    background: #eaeaea;
    color: #111827;
    border: 1px solid rgba(0, 0, 0, 0.06);
  }

  .toolbar .leave {
    background: #ef4444;
    color: #fff;
    border-color: #dc2626;
  }

  iframe {
    width: 100%;
    height: 100%;
    border: 0;
  }

  // button {
  //   position: absolute;
  //   top: 0.25rem;
  //   right: 0.75rem;
  // }
}
</style>
