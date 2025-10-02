import { API } from 'widget/helpers/axios';
import { buildSearchParamsWithLocale } from '../helpers/urlParamsHelper';

export default {
  addParticipantToDyteMeeting: messageId => {
    const search = buildSearchParamsWithLocale(window.location.search);
    const urlData = {
      url: `/api/v1/widget/integrations/dyte/add_participant_to_meeting${search}`,
    };
    return API.post(urlData.url, { message_id: messageId });
  },
  createDyteMeeting: () => {
    const search = buildSearchParamsWithLocale(window.location.search);
    const urlData = {
      url: `/api/v1/widget/integrations/dyte/create_a_meeting${search}`,
    };
    return API.post(urlData.url);
  },
  scheduleDyteCall: payload => {
    const search = buildSearchParamsWithLocale(window.location.search);
    const urlData = {
      url: `/api/v1/widget/integrations/dyte/schedule${search}`,
    };
    return API.post(urlData.url, payload);
  },
  joinDyte: payload => {
    const search = buildSearchParamsWithLocale(window.location.search);
    const urlData = {
      url: `/api/v1/widget/integrations/dyte/join${search}`,
    };
    return API.post(urlData.url, payload);
  },

  // Jitsi Meet Integration APIs
  addParticipantToJitsiMeeting: messageId => {
    const search = buildSearchParamsWithLocale(window.location.search);
    const urlData = {
      url: `/api/v1/widget/integrations/jitsi/add_participant_to_meeting${search}`,
    };
    return API.post(urlData.url, { message_id: messageId });
  },
  createJitsiMeeting: () => {
    const search = buildSearchParamsWithLocale(window.location.search);
    const urlData = {
      url: `/api/v1/widget/integrations/jitsi/create_a_meeting${search}`,
    };
    return API.post(urlData.url);
  },
  scheduleJitsiCall: payload => {
    const search = buildSearchParamsWithLocale(window.location.search);
    const urlData = {
      url: `/api/v1/widget/integrations/jitsi/schedule${search}`,
    };
    return API.post(urlData.url, payload);
  },
  joinJitsi: payload => {
    const search = buildSearchParamsWithLocale(window.location.search);
    const urlData = {
      url: `/api/v1/widget/integrations/jitsi/join${search}`,
    };
    return API.post(urlData.url, payload);
  },

  // Smart meeting creation that tries Jitsi first, then falls back to Dyte
  createVideoMeeting: () => {
    const search = buildSearchParamsWithLocale(window.location.search);
    
    // First try Jitsi (preferred)
    const jitsiUrl = `/api/v1/widget/integrations/jitsi/create_a_meeting${search}`;
    return API.post(jitsiUrl).catch(jitsiError => {
      // If Jitsi fails with 401/404/500, try Dyte as fallback
      console.log('Jitsi integration failed, trying Dyte fallback:', jitsiError.response?.status);
      const dyteUrl = `/api/v1/widget/integrations/dyte/create_a_meeting${search}`;
      return API.post(dyteUrl).catch(dyteError => {
        // If both fail, prefer the Jitsi error (since that's what we want to work)
        console.log('Both integrations failed. Jitsi error:', jitsiError.response?.status, 'Dyte error:', dyteError.response?.status);
        throw jitsiError;
      });
    });
  },
};
