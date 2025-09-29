<script>
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import { getContrastingTextColor } from '@chatwoot/utils';
import { mapGetters } from 'vuex';
import { emitter } from 'shared/helpers/mitt';

export default {
  components: {
    FluentIcon,
  },
  props: {
    messageId: {
      type: Number,
      required: true,
    },
    meetingData: {
      type: Object,
      required: true,
    },
  },
  data() {
    return { isLoading: false };
  },
  computed: {
    ...mapGetters({ widgetColor: 'appConfig/getWidgetColor' }),
    textColor() {
      return getContrastingTextColor(this.widgetColor);
    },
    integrationType() {
      // Check if room_name exists (Jitsi) or meeting_id exists (Dyte)
      if (this.meetingData?.room_name) {
        return 'jitsi';
      }
      return 'dyte'; // Default to Dyte for backward compatibility
    },
  },
  mounted() {
    // Auto-join handlers for both integration types
    this._dyteAutoJoinHandler = messageId => {
      if (messageId === this.messageId) {
        this.joinTheCall();
      }
    };
    this._jitsiAutoJoinHandler = messageId => {
      if (messageId === this.messageId) {
        this.joinTheCall();
      }
    };

    emitter.on('dyte:auto-join', this._dyteAutoJoinHandler);
    emitter.on('jitsi:auto-join', this._jitsiAutoJoinHandler);
  },
  beforeUnmount() {
    if (this._dyteAutoJoinHandler) {
      emitter.off('dyte:auto-join', this._dyteAutoJoinHandler);
    }
    if (this._jitsiAutoJoinHandler) {
      emitter.off('jitsi:auto-join', this._jitsiAutoJoinHandler);
    }
  },
  methods: {
    async joinTheCall() {
      if (this.integrationType === 'jitsi') {
        // Emit event to open video in JitsiPanel
        emitter.emit('jitsi:join-room', this.meetingData.room_name);
      } else {
        // Emit event to open video in DytePanel for backward compatibility
        emitter.emit('dyte:join-message', this.messageId);
      }
    },
  },
};
</script>

<template>
  <div>
    <button class="button join-call-button" color-scheme="secondary" :is-loading="isLoading" :style="{
      background: widgetColor,
      borderColor: widgetColor,
      color: textColor,
    }" @click="joinTheCall">
      <FluentIcon icon="video-add" class="rtl:ml-2 ltr:mr-2" />
      {{ $t(`INTEGRATIONS.${integrationType.toUpperCase()}.CLICK_HERE_TO_JOIN`) }}
    </button>
  </div>
</template>

<style lang="scss" scoped>
.join-call-button {
  @apply flex items-center my-2 rounded-lg;
}
</style>
