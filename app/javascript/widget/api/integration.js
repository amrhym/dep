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
};
