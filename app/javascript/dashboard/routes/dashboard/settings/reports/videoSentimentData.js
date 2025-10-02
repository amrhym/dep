// This file is kept for reference - data is now fetched from the heatmap API
// The structure below shows the expected format for the API response transformation

// Example shape for API results:
// VideoCall = {
//   id: number;
//   videoUrl: string;
//   audioUrl: string;
//   overallSentiment: string;
//   overallComment: string;
//   summary: string;
//   transcript: Array<{
//     speaker: string;
//     timestamp: string; // mm:ss
//     text: string;
//     sentiment: string;
//   }>;
//   topics: string[];
//   status: string;
//   processedAt: string;
// };

// Sample data (no longer used - kept for reference)
export const sampleVideoCalls = [
  {
    id: 1,
    videoUrl: 'https://dummyvideo.com/embed/123',
    audioUrl: 'https://dummyaudio.com/audio.mp3',
    overallSentiment: 'Very positive conversation with good engagement.',
    overallComment: 'The agent handled the customer very well.',
    summary:
      'Customer had an issue with account access, agent resolved it politely.',
    transcript: [
      {
        speaker: 'Agent',
        timestamp: '00:05',
        text: 'Hello, how can I help you today?',
        sentiment: 'Positive',
      },
      {
        speaker: 'Customer',
        timestamp: '00:12',
        text: 'I\'m having trouble with my account.',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Agent',
        timestamp: '00:25',
        text: 'I\'ll be happy to assist you with that.',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 2,
    videoUrl: 'https://dummyvideo.com/embed/124',
    audioUrl: 'https://dummyaudio.com/audio2.mp3',
    overallSentiment: 'Frustrated customer, but resolved satisfactorily.',
    overallComment: 'Agent showed patience and professionalism.',
    summary: 'Billing dispute resolved after thorough explanation.',
    transcript: [
      {
        speaker: 'Customer',
        timestamp: '00:02',
        text: 'I was charged twice for the same service!',
        sentiment: 'Negative',
      },
      {
        speaker: 'Agent',
        timestamp: '00:08',
        text: 'I understand your concern. Let me check your account.',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Agent',
        timestamp: '00:45',
        text: 'I can see the duplicate charge. I\'ll refund it immediately.',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 3,
    videoUrl: 'https://dummyvideo.com/embed/125',
    audioUrl: 'https://dummyaudio.com/audio3.mp3',
    overallSentiment: 'Neutral interaction with technical support.',
    overallComment: 'Standard technical troubleshooting session.',
    summary: 'Internet connectivity issue resolved with router reset.',
    transcript: [
      {
        speaker: 'Customer',
        timestamp: '00:03',
        text: 'My internet has been slow all day.',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Agent',
        timestamp: '00:10',
        text: 'Let\'s run some diagnostic tests to identify the issue.',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Customer',
        timestamp: '01:20',
        text: 'Great, it\'s working much better now!',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 4,
    videoUrl: 'https://dummyvideo.com/embed/126',
    audioUrl: 'https://dummyaudio.com/audio4.mp3',
    overallSentiment: 'Highly satisfied customer with product inquiry.',
    overallComment: 'Excellent sales interaction and product knowledge.',
    summary: 'Customer upgraded to premium plan after product demo.',
    transcript: [
      {
        speaker: 'Customer',
        timestamp: '00:01',
        text: 'I\'d like to know more about your premium features.',
        sentiment: 'Positive',
      },
      {
        speaker: 'Agent',
        timestamp: '00:06',
        text: 'I\'d be happy to show you the benefits of our premium plan.',
        sentiment: 'Positive',
      },
      {
        speaker: 'Customer',
        timestamp: '02:15',
        text: 'This looks perfect! I\'ll upgrade right now.',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 5,
    videoUrl: 'https://dummyvideo.com/embed/127',
    audioUrl: 'https://dummyaudio.com/audio5.mp3',
    overallSentiment: 'Challenging situation with upset customer.',
    overallComment: 'Agent handled escalation well despite difficult circumstances.',
    summary: 'Service outage complaint escalated to management.',
    transcript: [
      {
        speaker: 'Customer',
        timestamp: '00:01',
        text: 'This is unacceptable! I\'ve been without service for hours!',
        sentiment: 'Negative',
      },
      {
        speaker: 'Agent',
        timestamp: '00:08',
        text: 'I sincerely apologize for the inconvenience. Let me escalate this.',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Customer',
        timestamp: '01:45',
        text: 'Thank you for taking this seriously.',
        sentiment: 'Neutral',
      },
    ],
  },
  {
    id: 6,
    videoUrl: 'https://dummyvideo.com/embed/128',
    audioUrl: 'https://dummyaudio.com/audio6.mp3',
    overallSentiment: 'Pleasant conversation about service renewal.',
    overallComment: 'Smooth renewal process with satisfied customer.',
    summary: 'Annual subscription renewed with discount applied.',
    transcript: [
      {
        speaker: 'Agent',
        timestamp: '00:03',
        text: 'I see your subscription expires next week. Would you like to renew?',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Customer',
        timestamp: '00:10',
        text: 'Yes, and I heard there might be a loyalty discount?',
        sentiment: 'Positive',
      },
      {
        speaker: 'Agent',
        timestamp: '00:25',
        text: 'Absolutely! I can apply a 15% discount for loyal customers.',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 7,
    videoUrl: 'https://dummyvideo.com/embed/129',
    audioUrl: 'https://dummyaudio.com/audio7.mp3',
    overallSentiment: 'Informative session about new features.',
    overallComment: 'Agent provided comprehensive feature overview.',
    summary: 'Customer educated about recent platform updates.',
    transcript: [
      {
        speaker: 'Customer',
        timestamp: '00:05',
        text: 'I noticed some changes in the interface. What\'s new?',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Agent',
        timestamp: '00:12',
        text: 'We\'ve added several exciting features. Let me walk you through them.',
        sentiment: 'Positive',
      },
      {
        speaker: 'Customer',
        timestamp: '02:30',
        text: 'These updates look really useful. Thanks for the demo!',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 8,
    videoUrl: 'https://dummyvideo.com/embed/130',
    audioUrl: 'https://dummyaudio.com/audio8.mp3',
    overallSentiment: 'Mixed emotions during password reset assistance.',
    overallComment: 'Security-focused interaction handled appropriately.',
    summary: 'Password reset completed with additional security measures.',
    transcript: [
      {
        speaker: 'Customer',
        timestamp: '00:02',
        text: 'I can\'t remember my password and the reset isn\'t working.',
        sentiment: 'Negative',
      },
      {
        speaker: 'Agent',
        timestamp: '00:08',
        text: 'I\'ll help you reset it securely. Can you verify your identity first?',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Customer',
        timestamp: '01:15',
        text: 'Perfect! I\'m back in. Thank you for the security steps.',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 9,
    videoUrl: 'https://dummyvideo.com/embed/131',
    audioUrl: 'https://dummyaudio.com/audio9.mp3',
    overallSentiment: 'Positive feedback and testimonial session.',
    overallComment: 'Customer expressed high satisfaction with service.',
    summary: 'Long-term customer provided positive feedback and testimonial.',
    transcript: [
      {
        speaker: 'Customer',
        timestamp: '00:01',
        text: 'I wanted to share how happy I am with your service.',
        sentiment: 'Positive',
      },
      {
        speaker: 'Agent',
        timestamp: '00:07',
        text: 'That\'s wonderful to hear! We really appreciate loyal customers like you.',
        sentiment: 'Positive',
      },
      {
        speaker: 'Customer',
        timestamp: '01:20',
        text: 'I\'ve already recommended you to three friends!',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 10,
    videoUrl: 'https://dummyvideo.com/embed/132',
    audioUrl: 'https://dummyaudio.com/audio10.mp3',
    overallSentiment: 'Technical consultation with detailed explanation.',
    overallComment: 'Agent demonstrated strong technical expertise.',
    summary: 'Complex integration question answered with step-by-step guidance.',
    transcript: [
      {
        speaker: 'Customer',
        timestamp: '00:04',
        text: 'I need help integrating your API with our system.',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Agent',
        timestamp: '00:10',
        text: 'I\'d be happy to walk you through the integration process.',
        sentiment: 'Positive',
      },
      {
        speaker: 'Customer',
        timestamp: '03:45',
        text: 'This is exactly what I needed. Very clear instructions!',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 11,
    videoUrl: 'https://dummyvideo.com/embed/133',
    audioUrl: 'https://dummyaudio.com/audio11.mp3',
    overallSentiment: 'Concerned customer about data privacy.',
    overallComment: 'Agent addressed privacy concerns thoroughly.',
    summary: 'Data privacy questions answered with policy clarification.',
    transcript: [
      {
        speaker: 'Customer',
        timestamp: '00:02',
        text: 'I\'m concerned about how you handle my personal data.',
        sentiment: 'Negative',
      },
      {
        speaker: 'Agent',
        timestamp: '00:08',
        text: 'I understand your concern. Let me explain our privacy practices.',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Customer',
        timestamp: '02:10',
        text: 'That\'s reassuring. I feel much better about it now.',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 12,
    videoUrl: 'https://dummyvideo.com/embed/134',
    audioUrl: 'https://dummyaudio.com/audio12.mp3',
    overallSentiment: 'Friendly conversation about account settings.',
    overallComment: 'Helpful guidance on customizing account preferences.',
    summary: 'Account customization completed with user preferences.',
    transcript: [
      {
        speaker: 'Customer',
        timestamp: '00:05',
        text: 'Can you help me customize my notification settings?',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Agent',
        timestamp: '00:11',
        text: 'Certainly! Let\'s set up your preferences the way you like them.',
        sentiment: 'Positive',
      },
      {
        speaker: 'Customer',
        timestamp: '01:30',
        text: 'Perfect! This is much better for my workflow.',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 13,
    videoUrl: 'https://dummyvideo.com/embed/135',
    audioUrl: 'https://dummyaudio.com/audio13.mp3',
    overallSentiment: 'Urgent support request handled efficiently.',
    overallComment: 'Quick resolution of time-sensitive issue.',
    summary: 'Critical system error resolved within SLA timeframe.',
    transcript: [
      {
        speaker: 'Customer',
        timestamp: '00:01',
        text: 'URGENT: Our system is down and we need immediate help!',
        sentiment: 'Negative',
      },
      {
        speaker: 'Agent',
        timestamp: '00:05',
        text: 'I\'m prioritizing this immediately. Let me check your system status.',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Customer',
        timestamp: '00:50',
        text: 'Thank you! Everything is back online now.',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 14,
    videoUrl: 'https://dummyvideo.com/embed/136',
    audioUrl: 'https://dummyaudio.com/audio14.mp3',
    overallSentiment: 'Educational session about best practices.',
    overallComment: 'Agent provided valuable usage tips and recommendations.',
    summary: 'Customer learned optimization techniques for better performance.',
    transcript: [
      {
        speaker: 'Customer',
        timestamp: '00:03',
        text: 'Are there ways to optimize our current setup?',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Agent',
        timestamp: '00:09',
        text: 'Absolutely! I have several recommendations that could help.',
        sentiment: 'Positive',
      },
      {
        speaker: 'Customer',
        timestamp: '02:45',
        text: 'These tips are gold! I wish I knew this earlier.',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 15,
    videoUrl: 'https://dummyvideo.com/embed/137',
    audioUrl: 'https://dummyaudio.com/audio15.mp3',
    overallSentiment: 'Polite inquiry about service limits.',
    overallComment: 'Clear explanation of plan limitations and upgrade options.',
    summary: 'Service limits explained with upgrade path outlined.',
    transcript: [
      {
        speaker: 'Customer',
        timestamp: '00:06',
        text: 'I\'m hitting some limits on my current plan. What are my options?',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Agent',
        timestamp: '00:12',
        text: 'Let me review your usage and suggest the best upgrade path.',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Customer',
        timestamp: '01:40',
        text: 'That upgrade option sounds perfect for our needs.',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 16,
    videoUrl: 'https://dummyvideo.com/embed/138',
    audioUrl: 'https://dummyaudio.com/audio16.mp3',
    overallSentiment: 'Collaborative troubleshooting session.',
    overallComment: 'Customer and agent worked together effectively to solve the issue.',
    summary: 'Configuration issue resolved through systematic troubleshooting.',
    transcript: [
      {
        speaker: 'Customer',
        timestamp: '00:04',
        text: 'Something isn\'t working right, but I\'m not sure what.',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Agent',
        timestamp: '00:10',
        text: 'Let\'s work through this together step by step.',
        sentiment: 'Positive',
      },
      {
        speaker: 'Customer',
        timestamp: '02:20',
        text: 'Great teamwork! We figured it out together.',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 17,
    videoUrl: 'https://dummyvideo.com/embed/139',
    audioUrl: 'https://dummyaudio.com/audio17.mp3',
    overallSentiment: 'Professional consultation about enterprise features.',
    overallComment: 'Comprehensive discussion of enterprise-level capabilities.',
    summary: 'Enterprise features demonstrated with implementation timeline.',
    transcript: [
      {
        speaker: 'Customer',
        timestamp: '00:02',
        text: 'We\'re considering your enterprise solution. Can you tell me more?',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Agent',
        timestamp: '00:08',
        text: 'I\'d be delighted to show you our enterprise capabilities.',
        sentiment: 'Positive',
      },
      {
        speaker: 'Customer',
        timestamp: '04:15',
        text: 'This looks like exactly what our organization needs.',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 18,
    videoUrl: 'https://dummyvideo.com/embed/140',
    audioUrl: 'https://dummyaudio.com/audio18.mp3',
    overallSentiment: 'Casual check-in with long-term customer.',
    overallComment: 'Relationship-building conversation with valued customer.',
    summary: 'Routine account review with satisfied long-term customer.',
    transcript: [
      {
        speaker: 'Agent',
        timestamp: '00:03',
        text: 'Hi! Just checking in to see how everything is going.',
        sentiment: 'Positive',
      },
      {
        speaker: 'Customer',
        timestamp: '00:09',
        text: 'Everything\'s been running smoothly. Thanks for checking!',
        sentiment: 'Positive',
      },
      {
        speaker: 'Agent',
        timestamp: '00:45',
        text: 'Wonderful! Don\'t hesitate to reach out if you need anything.',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 19,
    videoUrl: 'https://dummyvideo.com/embed/141',
    audioUrl: 'https://dummyaudio.com/audio19.mp3',
    overallSentiment: 'Product return request handled professionally.',
    overallComment: 'Return process explained clearly with customer satisfaction maintained.',
    summary: 'Product return initiated with full refund processed.',
    transcript: [
      {
        speaker: 'Customer',
        timestamp: '00:01',
        text: 'I need to return a product that doesn\'t meet my needs.',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Agent',
        timestamp: '00:07',
        text: 'No problem at all. Let me walk you through our return process.',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Customer',
        timestamp: '01:25',
        text: 'Thank you for making this so easy and hassle-free.',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 20,
    videoUrl: 'https://dummyvideo.com/embed/142',
    audioUrl: 'https://dummyaudio.com/audio20.mp3',
    overallSentiment: 'Training session for new user onboarding.',
    overallComment: 'Comprehensive onboarding session with engaged new user.',
    summary: 'New customer successfully onboarded with full platform training.',
    transcript: [
      {
        speaker: 'Agent',
        timestamp: '00:02',
        text: 'Welcome! I\'m excited to help you get started with our platform.',
        sentiment: 'Positive',
      },
      {
        speaker: 'Customer',
        timestamp: '00:08',
        text: 'Thank you! I\'m eager to learn everything.',
        sentiment: 'Positive',
      },
      {
        speaker: 'Customer',
        timestamp: '03:30',
        text: 'This training was incredibly helpful. I feel confident now!',
        sentiment: 'Positive',
      },
    ],
  },
  {
    id: 21,
    videoUrl: 'https://dummyvideo.com/embed/143',
    audioUrl: 'https://dummyaudio.com/audio21.mp3',
    overallSentiment: 'Follow-up call after previous issue resolution.',
    overallComment: 'Excellent follow-up service ensuring customer satisfaction.',
    summary: 'Follow-up confirmed previous issue remained resolved.',
    transcript: [
      {
        speaker: 'Agent',
        timestamp: '00:01',
        text: 'I\'m calling to follow up on the issue we resolved last week.',
        sentiment: 'Neutral',
      },
      {
        speaker: 'Customer',
        timestamp: '00:07',
        text: 'Everything has been working perfectly since then!',
        sentiment: 'Positive',
      },
      {
        speaker: 'Agent',
        timestamp: '00:35',
        text: 'That\'s great to hear! We appreciate your patience.',
        sentiment: 'Positive',
      },
    ],
  },
];

// Example shape for future API results
// export type VideoCall = {
//   id: number;
//   videoUrl: string;
//   audioUrl: string;
//   overallSentiment: string;
//   overallComment: string;
//   summary: string;
//   transcript: Array<{
//     speaker: string;
//     timestamp: string; // mm:ss
//     text: string;
//     sentiment: string;
//   }>;
// };
