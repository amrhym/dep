/* global axios */

class VideoSentimentAPI {
    getConversations() {
        return axios.get('https://heatmap-cloud.xcai.io/api/v1/conversations', {
            headers: {
                'accept': 'application/json',
            }
        });
    }
}

export default new VideoSentimentAPI();
