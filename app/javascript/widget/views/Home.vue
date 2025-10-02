<script>
import TeamAvailability from 'widget/components/TeamAvailability.vue';
import { mapGetters } from 'vuex';
import { useRouter } from 'vue-router';
import configMixin from 'widget/mixins/configMixin';
import ArticleContainer from '../components/pageComponents/Home/Article/ArticleContainer.vue';
import ScheduleVideoCallForm from '../components/ScheduleVideoCallForm.vue';
import IntegrationAPIClient from 'widget/api/integration';
import { emitter } from 'shared/helpers/mitt';
import { ON_CONVERSATION_CREATED } from 'widget/constants/widgetBusEvents';
export default {
  name: 'Home',
  components: {
    ArticleContainer,
    TeamAvailability,
    ScheduleVideoCallForm,
  },
  mixins: [configMixin],
  setup() {
    const router = useRouter();
    return { router };
  },
  data() {
    return {
      showScheduleForm: false,
    };
  },
  computed: {
    ...mapGetters({
      availableAgents: 'agent/availableAgents',
      conversationSize: 'conversation/getConversationSize',
      unreadMessageCount: 'conversation/getUnreadMessageCount',
      // Provide widget color used in CTA styles
      widgetColor: 'appConfig/getWidgetColor',
    }),
  },
  mounted() {
    // Handle auto-start flow after conversation creation
    this._onConvCreated = async () => {
      if (window.chatwootDyteAutoStart) {
        try {
          const { data } = await IntegrationAPIClient.createJitsiMeeting();
          if (data && data.id) {
            // data.id is the integration message id, trigger join via message
            emitter.emit('video:join-message', data.id);
            // Also emit Jitsi event
            emitter.emit('jitsi:join-message', data.id);
          }
        } catch (e) {
          // ignore
        } finally {
          window.chatwootDyteAutoStart = false;
        }
      }
    };
    emitter.on(ON_CONVERSATION_CREATED, this._onConvCreated);
  },
  beforeUnmount() {
    if (this._onConvCreated) emitter.off(ON_CONVERSATION_CREATED, this._onConvCreated);
  },
  methods: {
    openSchedule() {
      this.showScheduleForm = true;
    },
    closeSchedule() {
      this.showScheduleForm = false;
    },
    startConversation() {
      if (this.preChatFormEnabled && !this.conversationSize) {
        return this.router.replace({ name: 'prechat-form' });
      }
      return this.router.replace({ name: 'messages' });
    },
    async startVideoCall() {
      // Set a temporary flag to trigger dyte flow on conversation creation
      window.chatwootDyteAutoStart = true;
      if (this.preChatFormEnabled && !this.conversationSize) {
        // Route to prechat form to collect info; meeting will be created after conversation is created
        return this.router.replace({ name: 'prechat-form' });
      }
      // No prechat required; create a conversation with a default message and then auto-create meeting
      try {
        await this.$store.dispatch('conversation/createConversation', {
          fullName: null,
          emailAddress: null,
          phoneNumber: null,
          message: this.$t ? this.$t('VIDEO.START') : 'Start video call',
          customAttributes: {},
        });
        // The ON_CONVERSATION_CREATED listener will create the meeting and auto-join
        this.router.replace({ name: 'messages' });
      } catch (e) {
        window.chatwootDyteAutoStart = false;
      }
    },
  },
};
</script>

<template>
  <div class="z-50 flex flex-col justify-end flex-1 w-full p-4 gap-4">
    <TeamAvailability :available-agents="availableAgents" :has-conversation="!!conversationSize"
      :unread-count="unreadMessageCount" @start-conversation="startConversation" />

    <ArticleContainer />

    <div class="flex flex-col gap-2">
      <button class="button join-call-button" @click="startVideoCall"
        :style="{ background: widgetColor, borderColor: widgetColor, color: '#fff' }">
        {{ $t ? $t('VIDEO.START_NOW') : 'Start video call now' }}
      </button>
      <button class="button" @click="openSchedule">
        {{ $t ? $t('VIDEO.SCHEDULE') : 'Schedule a video call' }}
      </button>
    </div>

    <ScheduleVideoCallForm v-if="showScheduleForm" @close="closeSchedule" />
  </div>
</template>
