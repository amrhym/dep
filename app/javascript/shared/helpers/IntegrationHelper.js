const DYTE_MEETING_LINK = 'https://app.dyte.io/v2/meeting';

export const buildDyteURL = dyteAuthToken => {
  return `${DYTE_MEETING_LINK}?authToken=${dyteAuthToken}&showSetupScreen=true&disableVideoBackground=true`;
};

// Jitsi Meet Integration
export const buildJitsiURL = (roomName, jwtToken = null) => {
  const baseUrl = import.meta.env.VITE_JITSI_URL || 'https://meet.jit.si';
  if (jwtToken) {
    return `${baseUrl}/${roomName}?jwt=${jwtToken}`;
  }
  return `${baseUrl}/${roomName}`;
};

// TODO [JITSI-AUTH]: Implement JWT token generation when backend supports it
export const getJitsiAuthToken = () => {
  return null; // For now, no JWT authentication
};
