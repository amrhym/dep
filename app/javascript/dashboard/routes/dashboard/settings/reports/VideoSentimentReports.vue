<script setup>
import ReportHeader from './components/ReportHeader.vue';
import Table from 'dashboard/components/table/Table.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Modal from 'dashboard/components/Modal.vue';
import { createColumnHelper, getCoreRowModel, useVueTable } from '@tanstack/vue-table';
import { computed, h, ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import videoSentimentAPI from 'dashboard/api/videoSentiment';

const { t } = useI18n();

// Data source from API
const rows = ref([]);
const isLoading = ref(false);
const error = ref(null);

// Function to transform API response to match component structure
const transformApiData = (apiData) => {
  if (!apiData || !apiData.conversations) return [];

  return apiData.conversations.map((conversation, index) => ({
    id: conversation._id || index,
    videoUrl: conversation.video_link || '',
    audioUrl: '', // Not provided in API response
    overallSentiment: conversation.sentiment || '',
    overallComment: conversation.comment || '',
    summary: conversation.summary || '',
    transcript: conversation.transcription_details?.map(detail => ({
      speaker: detail.speaker || 'Unknown',
      timestamp: formatTimestamp(detail.offset || 0),
      text: detail.text || '',
      sentiment: detail.sentiment || 'NEUTRAL',
    })) || [],
    topics: conversation.topics || [],
    status: conversation.status || '',
    processedAt: conversation.processed_at || '',
  }));
};

// Helper function to convert nanoseconds to mm:ss format
const formatTimestamp = (offsetNanoseconds) => {
  const seconds = Math.floor(offsetNanoseconds / 1000000000);
  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = seconds % 60;
  return `${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`;
};

// Function to fetch conversations from API
const fetchConversations = async () => {
  isLoading.value = true;
  error.value = null;

  try {
    const response = await videoSentimentAPI.getConversations();
    rows.value = transformApiData(response.data);
  } catch (err) {
    error.value = err.message || 'Failed to fetch conversations';
    console.error('Error fetching conversations:', err);
  } finally {
    isLoading.value = false;
  }
};

// Modal state
const showVideoModal = ref(false);
const videoSrc = ref('');

const showSentimentModal = ref(false);
const sentimentData = ref({ overallSentiment: '', overallComment: '', summary: '' });

const showTranscriptModal = ref(false);
const transcriptMessages = ref([]);

const columnHelper = createColumnHelper();

const columns = computed(() => [
  columnHelper.accessor('video', {
    header: t('VIDEO_SENTIMENT.TABLE.HEADER.VIDEO'),
    width: 180,
    cell: cellProps => {
      const row = cellProps.row.original;
      const hasVideo = row.videoUrl && row.videoUrl !== '';
      return hasVideo
        ? h(Button, {
          size: 'xs',
          label: t('VIDEO_SENTIMENT.ACTIONS.PLAY_VIDEO'),
          onClick: () => openVideo(row.videoUrl),
        })
        : h('span', { class: 'text-n-slate-11 text-sm' }, 'No video');
    },
  }),
  columnHelper.accessor('status', {
    header: 'Status',
    width: 120,
    cell: cellProps => {
      const status = cellProps.row.original.status;
      const statusClass = status === 'COMPLETED' ? 'text-green-600' : 'text-yellow-600';
      return h('span', { class: `text-sm ${statusClass}` }, status);
    },
  }),
  columnHelper.accessor('overallSentiment', {
    header: t('VIDEO_SENTIMENT.TABLE.HEADER.SENTIMENT'),
    width: 320,
    cell: cellProps => {
      const sentiment = cellProps.row.original.overallSentiment || '';
      const comment = cellProps.row.original.overallComment || '';
      const truncated = comment.length > 100 ? comment.slice(0, 100) + '…' : comment;
      return h(
        'button',
        {
          class: 'text-left text-n-slate-12 hover:underline',
          onClick: () =>
            openSentiment({
              overallSentiment: sentiment,
              overallComment: comment,
              summary: cellProps.row.original.summary,
            }),
        },
        h('div', { class: 'flex flex-col gap-1' }, [
          h('span', { class: 'font-medium text-xs' }, sentiment),
          h('span', { class: 'text-sm' }, truncated),
        ])
      );
    },
  }),
  columnHelper.accessor('transcript', {
    header: t('VIDEO_SENTIMENT.TABLE.HEADER.TRANSCRIPT'),
    width: 200,
    cell: cellProps => {
      const transcript = cellProps.row.original.transcript;
      const hasTranscript = transcript && transcript.length > 0;
      return hasTranscript
        ? h(Button, {
          size: 'xs',
          label: t('VIDEO_SENTIMENT.ACTIONS.VIEW_TRANSCRIPT'),
          onClick: () => openTranscript(transcript),
        })
        : h('span', { class: 'text-n-slate-11 text-sm' }, 'No transcript');
    },
  }),
  columnHelper.accessor('topics', {
    header: 'Topics',
    width: 200,
    cell: cellProps => {
      const topics = cellProps.row.original.topics || [];
      return h('div', { class: 'flex flex-wrap gap-1' },
        topics.map((topic, index) =>
          h('span', {
            key: index,
            class: 'px-2 py-1 bg-n-slate-4 text-xs rounded-md text-n-slate-11'
          }, topic)
        )
      );
    },
  }),
]);

const table = useVueTable({
  get data() {
    return rows.value;
  },
  get columns() {
    return columns.value;
  },
  enableSorting: false,
  getCoreRowModel: getCoreRowModel(),
});

function openVideo(src) {
  videoSrc.value = src;
  showVideoModal.value = true;
}

function openSentiment(payload) {
  sentimentData.value = payload;
  showSentimentModal.value = true;
}

function openTranscript(messages) {
  transcriptMessages.value = messages;
  showTranscriptModal.value = true;
}

// Fetch data when component mounts
onMounted(() => {
  fetchConversations();
});
</script>

<template>
  <ReportHeader :header-title="t('VIDEO_SENTIMENT.HEADER')" />

  <!-- Error state -->
  <div v-if="error" class="mt-5 p-4 bg-red-50 border border-red-200 rounded-xl">
    <div class="flex items-center">
      <div class="text-red-600 text-sm">
        {{ error }}
      </div>
      <Button size="xs" label="Retry" class="ml-auto" @click="fetchConversations" />
    </div>
  </div>

  <!-- Loading state -->
  <div v-else-if="isLoading"
    class="flex-1 overflow-auto px-2 py-2 mt-5 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2">
    <div class="flex items-center justify-center py-8">
      <div class="text-n-slate-11">Loading conversations...</div>
    </div>
  </div>

  <!-- Data table -->
  <div v-else
    class="flex-1 overflow-auto px-2 py-2 mt-5 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2">
    <Table :table="table" />

    <!-- Empty state -->
    <div v-if="rows.length === 0" class="flex items-center justify-center py-8">
      <div class="text-n-slate-11">No conversations found</div>
    </div>
  </div>

  <!-- Video modal -->
  <Modal v-model:show="showVideoModal" :on-close="() => (showVideoModal = false)" size="medium">
    <woot-modal-header :header-title="t('VIDEO_SENTIMENT.MODAL.VIDEO_TITLE')" />
    <div class="content">
      <div class="aspect-video w-full">
        <video class="w-full h-[28rem] rounded-md" :src="videoSrc" controls preload="metadata">
          Your browser does not support the video tag.
        </video>
      </div>
    </div>
  </Modal>

  <!-- Sentiment analysis modal -->
  <Modal v-model:show="showSentimentModal" :on-close="() => (showSentimentModal = false)">
    <woot-modal-header :header-title="t('VIDEO_SENTIMENT.MODAL.SENTIMENT_TITLE')" />
    <div class="content grid gap-4">
      <div>
        <h4 class="text-sm font-medium text-n-slate-11 mb-1">{{ t('VIDEO_SENTIMENT.FIELDS.OVERALL_SENTIMENT') }}</h4>
        <p class="m-0 text-n-slate-12">{{ sentimentData.overallSentiment || '--' }}</p>
      </div>
      <div>
        <h4 class="text-sm font-medium text-n-slate-11 mb-1">{{ t('VIDEO_SENTIMENT.FIELDS.OVERALL_COMMENT') }}</h4>
        <p class="m-0 text-n-slate-12">{{ sentimentData.overallComment || '--' }}</p>
      </div>
      <div>
        <h4 class="text-sm font-medium text-n-slate-11 mb-1">{{ t('VIDEO_SENTIMENT.FIELDS.SUMMARY') }}</h4>
        <p class="m-0 text-n-slate-12">{{ sentimentData.summary || '--' }}</p>
      </div>
    </div>
  </Modal>

  <!-- Transcript modal -->
  <Modal v-model:show="showTranscriptModal" :on-close="() => (showTranscriptModal = false)" size="medium">
    <woot-modal-header :header-title="t('VIDEO_SENTIMENT.MODAL.TRANSCRIPT_TITLE')" />
    <div class="content grid gap-3">
      <div v-for="(msg, idx) in transcriptMessages" :key="idx" class="flex">
        <!-- Chat-style bubbles: left for customer, right for agent -->
        <div class="flex w-full" :class="msg.speaker === 'Agent' ? 'justify-end' : 'justify-start'">
          <div class="max-w-lg rounded-xl px-4 py-3"
            :class="msg.speaker === 'Agent' ? 'bg-n-solid-blue text-n-slate-12 ltr:rounded-br-sm' : 'bg-n-slate-4 text-n-slate-12 ltr:rounded-bl-sm'">
            <div class="text-xs text-n-slate-11 mb-1 flex gap-2">
              <span class="font-medium">{{ msg.speaker }}</span>
              <span>{{ msg.timestamp }}</span>
              <span class="ml-auto">{{ msg.sentiment }}</span>
            </div>
            <div class="text-sm">{{ msg.text }}</div>
          </div>
        </div>
      </div>
    </div>
  </Modal>
</template>
