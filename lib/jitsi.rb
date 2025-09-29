class Jitsi
  include ActiveSupport::Configurable

  config_accessor :app_id, :secret_key, :base_url

  def initialize(app_id, secret_key)
    @app_id = app_id
    @secret_key = secret_key
    @base_url = ENV.fetch('JITSI_BASE_URL', 'https://jitsi.xdec.io')
  end

  # def generate_jwt_token(room_name, user_id, user_name, avatar_url, is_moderator = false)
  #   payload = {
  #     iss: @app_id,
  #     aud: 'jitsi',
  #     exp: 24.hours.from_now.to_i,
  #     room: room_name,
  #     sub: @base_url.gsub('https://', ''),
  #     context: {
  #       user: {
  #         id: user_id.to_s,
  #         name: user_name,
  #         avatar: avatar_url
  #       },
  #       features: {
  #         livestreaming: false,
  #         recording: false,
  #         transcription: false
  #       }
  #     },
  #     moderator: is_moderator
  #   }

  #   JWT.encode(payload, @secret_key, 'HS256')
  # end

  def build_meeting_url(room_name) # late will add jwt_token parameter
    raise 'Base URL is not configured' if @base_url.nil?

    # "#{@base_url}/#{room_name}?jwt=#{jwt_token}"
    "#{@base_url}/#{room_name}"
  end
end