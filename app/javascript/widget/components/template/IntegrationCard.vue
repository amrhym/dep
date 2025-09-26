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
  },
  data() {
    return { isLoading: false };
  },
  computed: {
    ...mapGetters({ widgetColor: 'appConfig/getWidgetColor' }),
    textColor() {
      return getContrastingTextColor(this.widgetColor);
    },
  },
  mounted() {
    // Auto-join when asked for this specific message id
    this._dyteAutoJoinHandler = messageId => {
      if (messageId === this.messageId) {
        this.joinTheCall();
      }
    };
    emitter.on('dyte:auto-join', this._dyteAutoJoinHandler);
  },
  beforeUnmount() {
    if (this._dyteAutoJoinHandler) {
      emitter.off('dyte:auto-join', this._dyteAutoJoinHandler);
    }
  },
  methods: {
    async joinTheCall() {
      // Emit event to open video in DytePanel instead of creating local iframe
      emitter.emit('dyte:join-message', this.messageId);
    },
  },
};
</script>

<template>
  <div>
    <button
      class="button join-call-button"
      color-scheme="secondary"
      :is-loading="isLoading"
      :style="{
        background: widgetColor,
        borderColor: widgetColor,
        color: textColor,
      }"
      @click="joinTheCall"
    >
      <FluentIcon icon="video-add" class="rtl:ml-2 ltr:mr-2" />
      {{ $t('INTEGRATIONS.DYTE.CLICK_HERE_TO_JOIN') }}
    </button>
  </div>
</template>

<style lang="scss" scoped>
.join-call-button {
  @apply flex items-center my-2 rounded-lg;
}
</style>
