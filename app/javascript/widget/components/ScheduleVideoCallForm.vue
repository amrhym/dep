<script>
import IntegrationAPIClient from 'widget/api/integration';

export default {
  name: 'ScheduleVideoCallForm',
  data() {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    const nowPlus30 = new Date(Date.now() + 30 * 60 * 1000);
    const pad = n => String(n).padStart(2, '0');
    const yyyy = nowPlus30.getFullYear();
    const MM = pad(nowPlus30.getMonth() + 1);
    const dd = pad(nowPlus30.getDate());
    const hh = pad(nowPlus30.getHours());
    const mm = pad(nowPlus30.getMinutes());
    return {
      scheduledAt: `${yyyy}-${MM}-${dd}T${hh}:${mm}`,
      scheduledTz: tz,
      notifyEmail: true,
      notifySms: false,
      notifyWhatsapp: false,
      customerEmail: '',
      customerPhone: '',
      isSubmitting: false,
      error: '',
    };
  },
  methods: {
    async submit() {
      this.isSubmitting = true;
      this.error = '';
      try {
        const local = new Date(this.scheduledAt);
        const payload = {
          scheduled_at: local.toISOString(),
          scheduled_tz: this.scheduledTz,
          notify_via: [
            this.notifyEmail ? 'email' : null,
            this.notifySms ? 'sms' : null,
            this.notifyWhatsapp ? 'whatsapp' : null,
          ].filter(Boolean),
          customer_email: this.customerEmail || undefined,
          customer_phone: this.customerPhone || undefined,
        };
        await IntegrationAPIClient.scheduleDyteCall(payload);
        this.$emit('close');
      } catch (e) {
        this.error = 'Failed to schedule the call. Please try again.';
      } finally {
        this.isSubmitting = false;
      }
    },
  },
};
</script>

<template>
  <div class="p-4 bg-n-background rounded-lg shadow">
    <h3 class="text-base font-medium mb-3">Schedule a video call</h3>
    <div class="flex flex-col gap-3">
      <label class="text-sm">
        Date &amp; Time
        <input type="datetime-local" v-model="scheduledAt" class="w-full border rounded px-2 py-1" />
      </label>
      <label class="text-sm">
        Timezone
        <input type="text" v-model="scheduledTz" class="w-full border rounded px-2 py-1" />
      </label>
      <div>
        <div class="text-sm font-medium mb-1">Notify via</div>
        <label class="flex items-center gap-2 text-sm">
          <input type="checkbox" v-model="notifyEmail" /> Email
        </label>
        <label class="flex items-center gap-2 text-sm">
          <input type="checkbox" v-model="notifySms" /> SMS
        </label>
        <label class="flex items-center gap-2 text-sm">
          <input type="checkbox" v-model="notifyWhatsapp" /> WhatsApp
        </label>
      </div>
      <label class="text-sm" v-if="notifyEmail">
        Customer Email
        <input type="email" v-model="customerEmail" class="w-full border rounded px-2 py-1" />
      </label>
      <label class="text-sm" v-if="notifySms || notifyWhatsapp">
        Customer Phone (E.164)
        <input type="tel" v-model="customerPhone" class="w-full border rounded px-2 py-1" />
      </label>
      <div v-if="error" class="text-sm text-n-ruby-10">{{ error }}</div>
      <div class="flex gap-2 mt-2">
        <button class="button" @click="$emit('close')">Cancel</button>
        <button class="button" :disabled="isSubmitting" @click="submit">
          {{ isSubmitting ? 'Scheduling…' : 'Schedule' }}
        </button>
      </div>
    </div>
  </div>
</template>