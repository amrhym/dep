<script>
import { ref, onMounted, onBeforeUnmount } from 'vue';
import IntegrationAPIClient from 'widget/api/integration';
import { emitter } from 'shared/helpers/mitt';
import { buildDyteURL } from 'shared/helpers/IntegrationHelper';

export default {
  name: 'DytePanel',
  setup() {
    const isVisible = ref(false);
    const isLoading = ref(false);
    const dyteToken = ref('');
    const meetingId = ref('');
    const panelRef = ref(null);

    const meetingLink = () => (dyteToken.value ? buildDyteURL(dyteToken.value) : '');
    const iframeSrc = () => meetingLink();

    const close = () => {
      isVisible.value = false;
      dyteToken.value = '';
      meetingId.value = '';
    };

    const enterFullscreen = async () => {
      try {
        if (panelRef.value && panelRef.value.requestFullscreen) {
          await panelRef.value.requestFullscreen();
        }
      } catch (e) {
        // ignore
      }
    };

    let pipWindow = null;
    const requestPiP = async () => {
      try {
        // Prefer Document Picture-in-Picture if supported
        if (window.documentPictureInPicture && typeof window.documentPictureInPicture.requestWindow === 'function') {
          pipWindow = await window.documentPictureInPicture.requestWindow({ width: 480, height: 270 });
          pipWindow.document.body.style.margin = '0';
          const iframe = pipWindow.document.createElement('iframe');
          iframe.src = meetingLink();
          iframe.allow = 'camera;microphone;fullscreen;display-capture;picture-in-picture;clipboard-write;';
          iframe.style.width = '100%';
          iframe.style.height = '100%';
          iframe.style.border = '0';
          pipWindow.document.body.appendChild(iframe);
          pipWindow.addEventListener('pagehide', () => { pipWindow = null; });
        } else {
          // Fallback to pop-out window
          const features = 'popup=yes,width=900,height=600,menubar=no,toolbar=no,location=no,status=no';
          window.open(meetingLink(), 'dyte_popout', features);
        }
      } catch (e) {
        // ignore
      }
    };

    const popout = () => {
      const features = 'popup=yes,width=900,height=600,menubar=no,toolbar=no,location=no,status=no';
      window.open(meetingLink(), 'dyte_popout', features);
    };

    const joinByScheduled = async scheduledId => {
      if (!scheduledId) return;
      isLoading.value = true;
      try {
        const { data } = await IntegrationAPIClient.joinDyte({ scheduled_id: scheduledId });
        if (data && data.token) {
          dyteToken.value = data.token;
          meetingId.value = data.meeting_id || '';
          isVisible.value = true;
        }
      } catch (e) {
        // noop
      } finally {
        isLoading.value = false;
      }
    };

    const joinByMeeting = async mId => {
      if (!mId) return;
      isLoading.value = true;
      try {
        const { data } = await IntegrationAPIClient.joinDyte({ meeting_id: mId });
        if (data && data.token) {
          dyteToken.value = data.token;
          meetingId.value = data.meeting_id || mId;
          isVisible.value = true;
        }
      } catch (e) {
        // noop
      } finally {
        isLoading.value = false;
      }
    };

    const onAutoJoin = mid => joinByMeeting(mid);
    const joinByMessage = async messageId => {
      if (!messageId) return;
      isLoading.value = true;
      try {
        const { data } = await IntegrationAPIClient.addParticipantToDyteMeeting(
          messageId
        );
        const tk = data && (data.token || data.auth_token);
        if (tk) {
          dyteToken.value = tk;
          isVisible.value = true;
        }
      } catch (e) {
        // noop
      } finally {
        isLoading.value = false;
      }
    };

    const parseUrlAndAutoJoin = () => {
      const params = new URLSearchParams(window.location.search);
      const auto = params.get('cw_autojoin');
      const sId = params.get('cw_scheduled_id');
      const mId = params.get('cw_meeting_id');
      if (auto === '1' || auto === 'true') {
        if (sId) return joinByScheduled(sId);
        if (mId) return joinByMeeting(mId);
      }
      return null;
    };

    onMounted(() => {
      emitter.on('dyte:auto-join', onAutoJoin);
      emitter.on('dyte:join-scheduled', joinByScheduled);
      emitter.on('dyte:join-message', joinByMessage);
      parseUrlAndAutoJoin();
    });

    onBeforeUnmount(() => {
      emitter.off('dyte:auto-join', onAutoJoin);
      emitter.off('dyte:join-scheduled', joinByScheduled);
      emitter.off('dyte:join-message', joinByMessage);
    });

    return { isVisible, isLoading, dyteToken, iframeSrc, close, panelRef, enterFullscreen, requestPiP, popout };
  },
};
</script>

<template>
  <div v-if="isVisible" class="dyte-panel" ref="panelRef">
    <div class="dyte-toolbar">
      <span class="title">Video call</span>
      <div class="spacer" />
      <button class="btn" title="Fullscreen" @click="enterFullscreen">⛶</button>
      <button class="btn" title="Picture-in-picture" @click="requestPiP">🗗</button>
      <button class="btn" title="Pop out" @click="popout">↗</button>
      <button class="close-btn" @click="close">×</button>
    </div>
    <div class="dyte-iframe-wrap">
      <iframe
        :src="iframeSrc()"
        allow="camera;microphone;fullscreen;display-capture;picture-in-picture;clipboard-write;"
      />
    </div>
  </div>
</template>

<style scoped>
.dyte-panel {
  display: flex;
  flex-direction: column;
  width: 100%;
  max-height: 50%;
  border-bottom: 1px solid rgba(0,0,0,0.06);
  background: var(--w-foreground, #fff);
}
  .dyte-toolbar {
    display: flex;
    align-items: center;
    gap: 8px;
    justify-content: flex-start;
    padding: 6px 10px;
  }
  .dyte-toolbar .title { font-weight: 600; }
  .dyte-toolbar .spacer { flex: 1; }
  .dyte-toolbar .btn {
    border: 1px solid rgba(0,0,0,0.1);
    background: transparent;
    font-size: 14px;
    padding: 2px 6px;
    border-radius: 4px;
    cursor: pointer;
  }
  .dyte-toolbar .close-btn {
    border: none;
    background: transparent;
    font-size: 20px;
    cursor: pointer;
  }
.dyte-iframe-wrap {
  width: 100%;
  height: 280px;
}
.dyte-iframe-wrap iframe {
  width: 100%;
  height: 100%;
  border: 0;
}
</style>