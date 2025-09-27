<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store.js';
import { API } from 'widget/helpers/axios';
import Spinner from 'shared/components/Spinner.vue';

const props = defineProps({
  conversation: {
    type: Object,
    default: () => ({}),
  },
  showPosition: {
    type: Boolean,
    default: true,
  },
  updateInterval: {
    type: Number,
    default: 30000, // 30 seconds
  },
});

const { t } = useI18n();

const loading = ref(true);
const waitData = ref({
  wait_time_minutes: null,
  message: '',
  position: null,
  status: 'offline',
  available_agents: 0,
});

let updateTimer = null;

const isWaiting = computed(() => {
  // Check conversation status from props or wait data
  const status = props.conversation?.status || waitData.value.conversation_status;
  const assigneeId = props.conversation?.assignee_id || waitData.value.assignee_id;
  return status === 'open' && !assigneeId;
});

const hasWaitTime = computed(() => {
  return waitData.value.wait_time_minutes !== null;
});

const queuePosition = computed(() => {
  return waitData.value.queue_position || waitData.value.position;
});

const showWaitInfo = computed(() => {
  // Always show for testing - will display wait info regardless of status
  return true;
});

const waitTimeClass = computed(() => {
  const minutes = waitData.value.wait_time_minutes;
  if (!minutes) return 'text-n-emerald-600';

  if (minutes <= 5) return 'text-n-emerald-600';
  if (minutes <= 15) return 'text-n-yellow-600';
  return 'text-n-orange-600';
});

const fetchWaitTime = async () => {
  try {
    const response = await API.get(`/api/v1/widget/conversations/wait_time${window.location.search}`);
    waitData.value = response.data;
    loading.value = false;
  } catch (error) {
    console.error('Failed to fetch wait time:', error);
    loading.value = false;
  }
};

const startUpdates = () => {
  fetchWaitTime();
  updateTimer = setInterval(fetchWaitTime, props.updateInterval);
};

const stopUpdates = () => {
  if (updateTimer) {
    clearInterval(updateTimer);
    updateTimer = null;
  }
};

onMounted(() => {
  console.log('WaitTimeDisplay mounted with conversation:', {
    id: props.conversation?.id,
    status: props.conversation?.status,
    assignee_id: props.conversation?.assignee_id,
    waiting_since: props.conversation?.waiting_since,
    isWaiting: isWaiting.value,
    showWaitInfo: showWaitInfo.value
  });

  // Always try to fetch wait time for testing, regardless of conversation status
  startUpdates();
});

onUnmounted(() => {
  stopUpdates();
});
</script>

<template>
  <div v-if="showWaitInfo" class="wait-time-container">
    <div class="bg-n-slate-50 rounded-lg p-3 border border-n-slate-200">
      <div v-if="loading" class="flex items-center justify-center py-2">
        <Spinner size="small" />
      </div>

      <div v-else class="space-y-2">
        <!-- Queue Position -->
        <div v-if="showPosition && queuePosition" class="flex items-center gap-2">
          <div class="w-6 h-6 rounded-full bg-n-slate-200 flex items-center justify-center">
            <span class="text-xs font-medium">#{{ queuePosition }}</span>
          </div>
          <span class="text-sm text-n-slate-600">
            {{ t('WAIT_TIME.POSITION_IN_QUEUE') }}
          </span>
        </div>

        <!-- Wait Time Message -->
        <div v-if="waitData.message || hasWaitTime" class="flex items-center gap-2">
          <svg
            class="w-4 h-4"
            :class="waitTimeClass"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <span class="text-sm font-medium" :class="waitTimeClass">
            {{ waitData.message || `Estimated wait time: ${waitData.wait_time_minutes} minutes` }}
          </span>
        </div>

        <!-- Agent Status -->
        <div v-if="waitData.status === 'offline'" class="text-xs text-n-slate-500">
          {{ t('WAIT_TIME.NO_AGENTS_ONLINE') }}
        </div>
        <div v-else-if="waitData.available_agents > 0" class="text-xs text-n-slate-500">
          {{ t('WAIT_TIME.AGENTS_AVAILABLE', { count: waitData.available_agents }) }}
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.wait-time-container {
  animation: slideIn 0.3s ease-out;
}

@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>