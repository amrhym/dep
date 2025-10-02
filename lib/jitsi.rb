require 'jwt'
require 'uri'

class Jitsi
  include ActiveSupport::Configurable

  config_accessor :app_id, :secret_key, :base_url

  def initialize(app_id = nil, secret_key = nil)
    @app_id = ENV.fetch('JITSI_APP_ID', 'cce719141dfe4b84fa89461a')
    @secret_key =  ENV.fetch('JITSI_SECRET_KEY', 'e819aa5ddfedab5590829d9c2da1e8f8eff370ee624ed3257a63a665273acda1')
    @base_url = ENV.fetch('JITSI_BASE_URL', 'https://jitsi.xdec.io')
  end

  def generate_jwt_token(room_name, _user_id, user_name, _avatar_url, _is_moderator = false, email = nil)
    p "app id: #{@app_id}, secret key: #{@secret_key}"
    raise 'App ID or Secret Key is not configured for Jitsi JWT' if @app_id.blank? || @secret_key.blank?

    # Allow overriding the JWT sub claim via env to match server configuration (eg: meet.jitsi)
    jwt_sub = ENV['JWT_SUB'].presence || ENV['JITSI_SUB'].presence || 'meet.jitsi'

    # Use dep_client_demo as both issuer and audience to match working JWT
    iss = ENV['JWT_ISS'].presence || 'dep_client_demo'
    aud = ENV['JWT_AUD'].presence || ENV['JWT_ACCEPTED_ISSUERS'].presence || 'dep_client_demo'
    jwt_room_all = ENV.fetch('JWT_ROOM_ALL', nil)
    truthy = %w[1 true yes on y].include?(jwt_room_all.to_s.strip.downcase)
    room_claim = truthy ? '*' : room_name
    p "room claim: #{room_claim}"
    p "room name: #{room_name}"

    payload = {
      context: {
        user: {
          name: user_name || 'Guest',
          email: email || ''
        }
      },
      aud: 'dep_client_demo',
      iss: 'dep_client_demo',
      sub: 'meet.jitsi',
      room: '*',
      iat: Time.now.to_i,
      exp: 1.hour.from_now.to_i

    }

    # JWT.encode(payload, @secret_key, 'HS256')
    JWT.encode(payload, @secret_key, 'HS256', { typ: 'JWT' })
  end

  def build_meeting_url(room_name, jwt_token = nil)
    raise 'Base URL is not configured' if @base_url.nil?

    p 'jwt token________:'
    p "Building meeting URL for room: #{room_name} with base URL: #{@base_url}"
    p "full URL: #{@base_url}/#{room_name}?jwt=#{jwt_token}"
    return "#{@base_url}/#{room_name}?jwt=#{jwt_token}" if jwt_token.present?

    "#{@base_url}/#{room_name}"
  end
end
