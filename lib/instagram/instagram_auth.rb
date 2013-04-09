require "faraday"
require "json"
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "envs")

class InstagramAuth

  attr_reader :instagram_auth_response

  INSTAGRAM_OAUTH_HOST = "https://api.instagram.com"
  INSTAGRAM_EXCHANGE_PATH = "/oauth/access_token"
  def initialize(code, redirect_path, query_string)
    @redirect_url = APP_URL + redirect_path
    
    request_params = {
      "code" => code,
      "client_id" => INSTAGRAM_CLIENT_ID,
      "client_secret" => INSTAGRAM_CLIENT_SECRET,
      "grant_type" => "authorization_code",
      "redirect_uri" => "http://#{@redirect_url}"
    }

    request_params = request_params.map { |key, value| "#{key}=#{value}" }.join("&")

    response = FaradayConnections.get(INSTAGRAM_OAUTH_HOST).post do |req|
      req.url INSTAGRAM_EXCHANGE_PATH
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = request_params
    end

    @instagram_auth_response = JSON.parse(response.body)
  end

end
