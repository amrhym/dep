<script>
import { ref, onMounted, onBeforeUnmount } from 'vue';
import { emitter } from 'shared/helpers/mitt';
import { buildJitsiURL, getJitsiAuthTokenFromResponse } from 'shared/helpers/IntegrationHelper';
import IntegrationAPIClient from 'widget/api/integration';

export default {
  name: 'JitsiPanel',
  setup() {
    const isVisible = ref(false);
    const isLoading = ref(false);
    const roomName = ref('');
    const panelRef = ref(null);
    const isFullscreen = ref(false);

    const currentJwt = ref(null);
    const iframeSrc = () => {
      if (!roomName.value) return '';
      console.log('JitsiPanel - roomName:', roomName.value);
      console.log('JitsiPanel - currentJwt:', currentJwt.value);
      const url = buildJitsiURL(roomName.value, currentJwt.value);
      console.log('JitsiPanel iframe URL:', url);
      return url;
    };

    const close = () => {
      isVisible.value = false;
      roomName.value = '';
    };

    // Listen for fullscreen changes
    const handleFullscreenChange = () => {
      isFullscreen.value = !!document.fullscreenElement;
    };

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

    let pipWindow = null;
    const requestPiP = async () => {
      try {
        if (window.documentPictureInPicture && typeof window.documentPictureInPicture.requestWindow === 'function') {
          pipWindow = await window.documentPictureInPicture.requestWindow({ width: 480, height: 270 });
          pipWindow.document.body.style.margin = '0';
          const iframe = pipWindow.document.createElement('iframe');
          iframe.src = iframeSrc();
          iframe.allow = 'camera;microphone;fullscreen;display-capture;picture-in-picture;clipboard-write;';
          iframe.style.width = '100%';
          iframe.style.height = '100%';
          iframe.style.border = '0';
          pipWindow.document.body.appendChild(iframe);
          pipWindow.addEventListener('pagehide', () => { pipWindow = null; });
        } else {
          const features = 'popup=yes,width=900,height=600,menubar=no,toolbar=no,location=no,status=no';
          window.open(iframeSrc(), 'jitsi_popout', features);
        }
      } catch (e) { }
    };

    const popout = () => {
      const features = 'popup=yes,width=900,height=600,menubar=no,toolbar=no,location=no,status=no';
      window.open(iframeSrc(), 'jitsi_popout', features);
    };

    const joinByRoom = (rn, preserveJwt = false) => {
      if (!rn) return;
      console.log('JitsiPanel - joinByRoom called with:', rn);
      if (!preserveJwt) {
        console.log('JitsiPanel - JWT will be null (no API call made)');
        currentJwt.value = null;
      } else {
        console.log('JitsiPanel - Preserving existing JWT:', currentJwt.value);
      }
      roomName.value = rn;
      isVisible.value = true;
    };

    const joinByMessage = async messageId => {
      if (!messageId) return;
      console.log('JitsiPanel - joinByMessage called with:', messageId);
      isLoading.value = true;
      try {
        const { data } = await IntegrationAPIClient.addParticipantToJitsiMeeting(messageId);
        console.log('JitsiPanel - API response data:', data);
        const rn = data?.room_name;
        const url = data?.meeting_url;
        currentJwt.value = getJitsiAuthTokenFromResponse(data);
        console.log('JitsiPanel - extracted JWT:', currentJwt.value);
        if (rn) {
          joinByRoom(rn, true); // preserve JWT
        } else if (url) {
          // Extract room from URL path as a fallback
          try {
            const u = new URL(url);
            const parts = u.pathname.split('/').filter(Boolean);
            if (parts.length) joinByRoom(parts[parts.length - 1], true); // preserve JWT
          } catch (e) {
            // noop
          }
        }
      } catch (e) {
        // noop
      } finally {
        isLoading.value = false;
      }
    };

    const parseUrlAndAutoJoin = async () => {
      const params = new URLSearchParams(window.location.search);
      const auto = params.get('cw_autojoin');
      const sId = params.get('cw_scheduled_id');
      const rn = params.get('cw_room_name');
      if (auto === '1' || auto === 'true') {
        // If explicit room is provided, join immediately
        if (rn) return joinByRoom(rn);
        // If scheduled id is present, resolve via backend and join
        if (sId) {
          try {
            const { data } = await IntegrationAPIClient.joinJitsi({ scheduled_id: sId });
            const jrn = data?.room_name;
            const url = data?.meeting_url;

            currentJwt.value = getJitsiAuthTokenFromResponse(data);
            if (jrn) return joinByRoom(jrn, true); // preserve JWT
            if (url) {
              try {
                const u = new URL(url);
                const parts = u.pathname.split('/').filter(Boolean);
                if (parts.length) return joinByRoom(parts[parts.length - 1], true); // preserve JWT
              } catch (e) { /* noop */ }
            }
          } catch (e) { /* noop */ }
        }
      }
      return null;
    };

    onMounted(() => {
      emitter.on('jitsi:join-room', joinByRoom);
      emitter.on('jitsi:join-message', joinByMessage);
      document.addEventListener('fullscreenchange', handleFullscreenChange);
      parseUrlAndAutoJoin();
    });

    onBeforeUnmount(() => {
      emitter.off('jitsi:join-room', joinByRoom);
      emitter.off('jitsi:join-message', joinByMessage);
      document.removeEventListener('fullscreenchange', handleFullscreenChange);
      if (pipWindow && !pipWindow.closed) {
        try { pipWindow.close(); } catch (e) { }
      }
      pipWindow = null;

      // Exit fullscreen if active
      if (isFullscreen.value && document.exitFullscreen) {
        try { document.exitFullscreen(); } catch (e) { }
      }
    });

    return { isVisible, isLoading, iframeSrc, close, panelRef, enterFullscreen, requestPiP, popout, isFullscreen };
  },
};
</script>

<template>
  <div v-if="isVisible" class="dyte-panel" ref="panelRef">
    <div class="dyte-toolbar">
      <span class="title">Video call</span>
      <div class="spacer" />
      <button class="btn" :title="isFullscreen ? 'Exit Fullscreen' : 'Fullscreen'" @click="enterFullscreen">
        {{ isFullscreen ? '⛶ Exit' : '⛶' }}
      </button>
      <!-- <button class="btn" title="Picture-in-picture" @click="requestPiP">🗗</button> -->
      <!-- <button class="btn" title="Pop out" @click="popout">↗</button> -->
      <button class="close-btn" @click="close">×</button>
    </div>
    <div class="dyte-iframe-wrap">
      <!-- Debug: Show the actual iframe URL -->
      <!-- <div style="font-size: 12px; padding: 4px; background: #f0f0f0; word-break: break-all;">
        Iframe URL: {{ iframeSrc() }}
      </div> -->
      <iframe :src="iframeSrc()"
        allow="camera;microphone;fullscreen;display-capture;picture-in-picture;clipboard-write;" />
    </div>
  </div>

</template>

<style scoped>
.dyte-panel {
  display: flex;
  flex-direction: column;
  width: 100%;
  height: 320px;
  max-height: 40vh;
  border-bottom: 2px solid rgba(0, 0, 0, 0.1);
  background: var(--w-foreground, #fff);
  position: relative;
  z-index: 10;
}

.dyte-toolbar {
  display: flex;
  align-items: center;
  gap: 8px;
  justify-content: flex-start;
  padding: 6px 10px;
}

.dyte-toolbar .title {
  font-weight: 600;
}

.dyte-toolbar .spacer {
  flex: 1;
}

.dyte-toolbar .btn {
  border: 1px solid rgba(0, 0, 0, 0.1);
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
  flex: 1;
  min-height: 280px;
  overflow: hidden;
}

.dyte-iframe-wrap iframe {
  width: 100%;
  height: 100%;
  border: 0;
}
</style>
