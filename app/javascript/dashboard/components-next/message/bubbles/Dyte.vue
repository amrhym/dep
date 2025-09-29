<script setup>
import { computed, ref } from 'vue';
import DyteAPI from 'dashboard/api/integrations/dyte';
import { buildDyteURL } from 'shared/helpers/IntegrationHelper';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

import { useMessageContext } from '../provider.js';
import BaseAttachmentBubble from './BaseAttachment.vue';

const { content, sender, id } = useMessageContext();

const { t } = useI18n();

const isLoading = ref(false);
const dyteAuthToken = ref('');

const meetingLink = computed(() => {
  return buildDyteURL(dyteAuthToken.value);
});

const panelRef = ref(null);
const enterFullscreen = async () => {
  try {
    if (panelRef.value && panelRef.value.requestFullscreen) {
      await panelRef.value.requestFullscreen();
    }
  } catch (e) { }
};

let pipWindow = null;
const requestPiP = async () => {
  try {
    if (window.documentPictureInPicture && typeof window.documentPictureInPicture.requestWindow === 'function') {
      pipWindow = await window.documentPictureInPicture.requestWindow({ width: 480, height: 270 });
      pipWindow.document.body.style.margin = '0';
      const iframe = pipWindow.document.createElement('iframe');
      iframe.src = meetingLink.value;
      iframe.allow = 'camera;microphone;fullscreen;display-capture;picture-in-picture;clipboard-write;';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.style.border = '0';
      pipWindow.document.body.appendChild(iframe);
      pipWindow.addEventListener('pagehide', () => { pipWindow = null; });
    } else {
      const features = 'popup=yes,width=900,height=600,menubar=no,toolbar=no,location=no,status=no';
      window.open(meetingLink.value, 'dyte_popout', features);
    }
  } catch (e) { }
};

const popout = () => {
  const features = 'popup=yes,width=900,height=600,menubar=no,toolbar=no,location=no,status=no';
  window.open(meetingLink.value, 'dyte_popout', features);
};

const joinTheCall = async () => {
  isLoading.value = true;
  try {
    const { data: { token } = {} } = await DyteAPI.addParticipantToMeeting(
      id.value
    );
    dyteAuthToken.value = token;
  } catch (err) {
    useAlert(t('INTEGRATION_SETTINGS.DYTE.JOIN_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const leaveTheRoom = () => {
  dyteAuthToken.value = '';
};
const action = computed(() => ({
  label: t('INTEGRATION_SETTINGS.DYTE.CLICK_HERE_TO_JOIN'),
  onClick: joinTheCall,
}));
</script>

<template>
  <BaseAttachmentBubble icon="i-ph-video-camera-fill" icon-bg-color="bg-[#2781F6]"
    sender-translation-key="CONVERSATION.SHARED_ATTACHMENT.MEETING" :action="action">
    <div v-if="!sender" class="text-sm truncate text-n-slate-12">
      <!-- Added as a fallback, where the sender is not available (Deleted) -->
      <!-- Will show the content, if senderName in BaseAttachment.vue is empty -->
      {{ content }}
    </div>
    <div v-if="dyteAuthToken" class="video-call--container" ref="panelRef">
      <div class="toolbar">
        <button class="btn" @click="enterFullscreen">⛶ Fullscreen</button>
        <button class="btn" @click="requestPiP">🗗 PiP</button>
        <button class="btn" @click="popout">↗ Pop out</button>
        <button class="btn leave" @click="leaveTheRoom">
          {{ $t('INTEGRATION_SETTINGS.DYTE.LEAVE_THE_ROOM') }}
        </button>
      </div>
      <iframe :src="meetingLink"
        allow="camera;microphone;fullscreen;display-capture;picture-in-picture;clipboard-write;" />
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
  position: relative;
  width: 100%;
  height: 420px;
  z-index: 1;
  padding: 0.25rem;
  @apply bg-n-background;

  .toolbar {
    display: flex;
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
