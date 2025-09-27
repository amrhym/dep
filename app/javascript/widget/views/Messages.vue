<script setup>
import { computed, onMounted } from 'vue';
import { useStore } from 'vuex';

import ChatFooter from '../components/ChatFooter.vue';
import ConversationWrap from '../components/ConversationWrap.vue';
import DytePanel from '../components/DytePanel.vue';
import WaitTimeDisplay from '../components/WaitTime/WaitTimeDisplay.vue';

const store = useStore();

const groupedMessages = computed(() =>
  store.getters['conversation/getGroupedConversation']
);

const currentConversation = computed(() =>
  store.getters['conversation/currentConversation']
);

const conversationAttributes = computed(() =>
  store.getters['conversationAttributes/getConversationParams']
);

// Create a combined conversation object with all the needed properties
const conversationData = computed(() => {
  const conv = currentConversation.value || {};
  const attrs = conversationAttributes.value || {};

  // Merge with attrs taking precedence only if value is not null/undefined/empty string
  const merged = { ...conv };
  Object.entries(attrs).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      merged[key] = value;
    }
  });

  return merged;
});

onMounted(() => {
  store.dispatch('conversation/setUserLastSeen');
});
</script>

<template>
  <div
    class="flex flex-col flex-1 overflow-hidden rounded-b-lg bg-n-slate-2 dark:bg-n-solid-1"
    style="height: 100%; position: relative;"
  >
    <DytePanel />
    <!-- Wait Time Display - Always show for testing -->
    <WaitTimeDisplay
      :conversation="conversationData"
      class="px-5 pt-3"
    />
    <div class="flex flex-1 overflow-auto" style="min-height: 0;">
      <ConversationWrap :grouped-messages="groupedMessages" />
    </div>
    <ChatFooter class="px-5" />
  </div>
</template>
