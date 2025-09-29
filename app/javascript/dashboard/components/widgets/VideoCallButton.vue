<script>
import { mapGetters } from 'vuex';
import DyteAPI from 'dashboard/api/integrations/dyte';
import JitsiAPI from 'dashboard/api/integrations/jitsi';
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
    videoIntegration() {
      // Check if Jitsi should be forced as primary integration
      const forceJitsi = true

      if (forceJitsi) {
        // Force Jitsi as primary - check if it exists in integrations
        let integration = this.appIntegrations.find(
          integration => integration.id === 'jitsi'
        );
        if (integration) {
          return integration;
        }
      }

      // Priority order: Jitsi with hooks > Jitsi without hooks > Dyte with hooks

      // First check for Jitsi with hooks
      let integration = this.appIntegrations.find(
        integration => integration.id === 'jitsi' && !!integration.hooks.length
      );

      if (!integration) {
        // Then check for Jitsi without hooks (can work with defaults)
        integration = this.appIntegrations.find(
          integration => integration.id === 'jitsi'
        );
      }

      if (!integration) {
        // Finally fallback to Dyte with hooks
        integration = this.appIntegrations.find(
          integration => integration.id === 'dyte' && !!integration.hooks.length
        );
      }

      return integration;
    },
    isVideoIntegrationEnabled() {
      return !!this.videoIntegration;
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
        if (this.videoIntegration?.id === 'jitsi') {
          await JitsiAPI.createAMeeting(this.conversationId);
        } else {
          // Default to Dyte for backward compatibility
          await DyteAPI.createAMeeting(this.conversationId);
        }
      } catch (error) {
        const integrationType = this.videoIntegration?.id?.toUpperCase() || 'DYTE';
        useAlert(this.$t(`INTEGRATION_SETTINGS.${integrationType}.CREATE_ERROR`));
      } finally {
        this.isLoading = false;
      }
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <NextButton v-if="isVideoIntegrationEnabled" v-tooltip.top-end="$t(`INTEGRATION_SETTINGS.${videoIntegration?.id?.toUpperCase() || 'DYTE'}.START_VIDEO_CALL_HELP_TEXT`)
    " icon="i-ph-video-camera" slate faded sm @click="onClick" />
</template>
