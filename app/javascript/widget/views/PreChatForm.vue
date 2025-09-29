<script>
import { mapActions } from 'vuex';
import { useRouter } from 'vue-router';
import PreChatForm from '../components/PreChat/Form.vue';
import configMixin from '../mixins/configMixin';
import { isEmptyObject } from 'widget/helpers/utils';
import { ON_CONVERSATION_CREATED } from '../constants/widgetBusEvents';
import { emitter } from 'shared/helpers/mitt';
import IntegrationAPIClient from 'widget/api/integration';

export default {
  components: {
    PreChatForm,
  },
  mixins: [configMixin],
  setup() {
    const router = useRouter();
    return { router };
  },
  mounted() {
    // Register event listener for conversation creation
    emitter.on(ON_CONVERSATION_CREATED, this.handleConversationCreated);
  },
  beforeUnmount() {
    emitter.off(ON_CONVERSATION_CREATED, this.handleConversationCreated);
  },
  methods: {
    ...mapActions('conversation', ['clearConversations']),
    ...mapActions('conversationAttributes', ['clearConversationAttributes']),
    async handleConversationCreated() {
      // Redirect to messages page after conversation is created
      this.router.replace({ name: 'messages' });
      // Auto-create and join video meeting if requested from Home
      if (window.chatwootDyteAutoStart) {
        try {
          const { data } = await IntegrationAPIClient.createJitsiMeeting();
          if (data && data.id) {
            emitter.emit('video:auto-join', data.id);
            // Also emit Jitsi event  
            emitter.emit('jitsi:auto-join', data.id);
          }
        } catch (e) {
          // ignore
        } finally {
          window.chatwootDyteAutoStart = false;
        }
      }
      // Only after successful navigation, reset the isUpdatingRoute UIflag in app/javascript/widget/router.js
      // See issue: https://github.com/chatwoot/chatwoot/issues/10736
    },

    onSubmit({
      fullName,
      emailAddress,
      message,
      activeCampaignId,
      phoneNumber,
      contactCustomAttributes,
      conversationCustomAttributes,
    }) {
      if (activeCampaignId) {
        emitter.emit('execute-campaign', {
          campaignId: activeCampaignId,
          customAttributes: conversationCustomAttributes,
        });
        this.$store.dispatch('contacts/update', {
          user: {
            email: emailAddress,
            name: fullName,
            phone_number: phoneNumber,
          },
        });
      } else {
        this.clearConversations();
        this.clearConversationAttributes();
        this.$store.dispatch('conversation/createConversation', {
          fullName: fullName,
          emailAddress: emailAddress,
          message: message,
          phoneNumber: phoneNumber,
          customAttributes: conversationCustomAttributes,
        });
      }
      if (!isEmptyObject(contactCustomAttributes)) {
        this.$store.dispatch(
          'contacts/setCustomAttributes',
          contactCustomAttributes
        );
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-1 overflow-auto">
    <PreChatForm :options="preChatFormOptions" @submit-pre-chat="onSubmit" />
  </div>
</template>
