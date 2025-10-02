<script setup>
import ReportHeader from './components/ReportHeader.vue';
import Table from 'dashboard/components/table/Table.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Modal from 'dashboard/components/Modal.vue';
import { createColumnHelper, getCoreRowModel, useVueTable } from '@tanstack/vue-table';
import { computed, h, ref } from 'vue';
import { sampleVideoCalls } from './videoSentimentData';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();

// Data source (replace later with API)
const rows = ref(sampleVideoCalls);

// Modal state
const showVideoModal = ref(false);
const videoSrc = ref('');

const playingAudioId = ref(null);

const showSentimentModal = ref(false);
const sentimentData = ref({ overallSentiment: '', overallComment: '', summary: '' });

const showTranscriptModal = ref(false);
const transcriptMessages = ref([]);

const columnHelper = createColumnHelper();

const columns = computed(() => [
  columnHelper.accessor('video', {
    header: t('VIDEO_SENTIMENT.TABLE.HEADER.VIDEO'),
    width: 180,
    cell: cellProps =>
      h(Button, {
        size: 'xs',
        label: t('VIDEO_SENTIMENT.ACTIONS.PLAY_VIDEO'),
        onClick: () => openVideo(cellProps.row.original.videoUrl),
      }),
  }),
  columnHelper.accessor('audio', {
    header: t('VIDEO_SENTIMENT.TABLE.HEADER.AUDIO'),
    width: 180,
    cell: cellProps => {
      const row = cellProps.row.original;
      const isPlaying = playingAudioId.value === row.id;
      return h('div', { class: 'flex flex-col gap-2' }, [
        h(Button, {
          size: 'xs',
          label: t('VIDEO_SENTIMENT.ACTIONS.PLAY_AUDIO'),
          onClick: () => toggleAudio(row.id, row.audioUrl),
        }),
        isPlaying
          ? h('audio', {
              src: row.audioUrl,
              controls: true,
              class: 'w-full',
            })
          : null,
      ]);
    },
  }),
  columnHelper.accessor('overallSentiment', {
    header: t('VIDEO_SENTIMENT.TABLE.HEADER.SENTIMENT'),
    width: 320,
    cell: cellProps => {
      const text = cellProps.row.original.overallSentiment || '';
      const truncated = text.length > 100 ? text.slice(0, 100) + '…' : text;
      return h(
        'button',
        {
          class: 'text-left text-n-slate-12 hover:underline',
          onClick: () =>
            openSentiment({
              overallSentiment: cellProps.row.original.overallSentiment,
              overallComment: cellProps.row.original.overallComment,
              summary: cellProps.row.original.summary,
            }),
        },
        truncated
      );
    },
  }),
  columnHelper.accessor('transcript', {
    header: t('VIDEO_SENTIMENT.TABLE.HEADER.TRANSCRIPT'),
    width: 200,
    cell: cellProps =>
      h(Button, {
        size: 'xs',
        label: t('VIDEO_SENTIMENT.ACTIONS.VIEW_TRANSCRIPT'),
        onClick: () => openTranscript(cellProps.row.original.transcript),
      }),
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

function toggleAudio(id, src) {
  playingAudioId.value = playingAudioId.value === id ? null : id;
}

function openSentiment(payload) {
  sentimentData.value = payload;
  showSentimentModal.value = true;
}

function openTranscript(messages) {
  transcriptMessages.value = messages;
  showTranscriptModal.value = true;
}
</script>

<template>
  <ReportHeader :header-title="t('VIDEO_SENTIMENT.HEADER')" />
  <div class="flex-1 overflow-auto px-2 py-2 mt-5 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2">
    <Table :table="table" />
  </div>

  <!-- Video modal -->
  <Modal v-model:show="showVideoModal" :on-close="() => (showVideoModal = false)" size="medium">
    <woot-modal-header :header-title="t('VIDEO_SENTIMENT.MODAL.VIDEO_TITLE')" />
    <div class="content">
      <div class="aspect-video w-full">
        <iframe
          class="w-full h-[28rem] rounded-md"
          :src="videoSrc"
          title="Video Player"
          frameborder="0"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
          allowfullscreen
        />
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
      <div
        v-for="(msg, idx) in transcriptMessages"
        :key="idx"
        class="flex"
      >
        <!-- Chat-style bubbles: left for customer, right for agent -->
        <div class="flex w-full" :class="msg.speaker === 'Agent' ? 'justify-end' : 'justify-start'">
          <div
            class="max-w-lg rounded-xl px-4 py-3"
            :class="msg.speaker === 'Agent' ? 'bg-n-solid-blue text-n-slate-12 ltr:rounded-br-sm' : 'bg-n-slate-4 text-n-slate-12 ltr:rounded-bl-sm'"
          >
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
