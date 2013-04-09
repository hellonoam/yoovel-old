require "uri"
require "json"
require "faraday"
require "rexml/document"
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "envs")
require "active_support/core_ext"

class GoogleAuth

  attr_reader :google_oauth_response

  GOOGLE_OAUTH_HOST = "https://accounts.google.com"
  OAUTH_EXCHANGE_PATH = "/o/oauth2/token"
  GOOGLE_OAUTH_PATHS = {
    "USER_INFO" => "https://www.googleapis.com/oauth2/v1/userinfo?",
    "GMAIL_ATOM" => "https://mail.google.com/mail/feed/atom",
    "ALL_CONTACTS" => "https://www.google.com/m8/feeds/contacts/default/full"
  }

  # Semantic requirement from Google
  GRANT_TYPE = "authorization_code"

  def initialize(code, redirect_path)
    @redirect_url = APP_URL + redirect_path

    # TODO(snir) parallelize this

    request_params = {
      "code" => code,
      "client_id" => GOOGLE_CLIENT_ID,
      "client_secret" => GOOGLE_CLIENT_SECRET,
      "redirect_uri" => "http://#{@redirect_url}",
      "grant_type" => GRANT_TYPE
    }

    request_params = request_params.map { |key, value| "#{key}=#{value}" }.join("&")

    response = FaradayConnections.get(GOOGLE_OAUTH_HOST).post do |req|
      req.url OAUTH_EXCHANGE_PATH
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = request_params
    end

    begin
      @google_oauth_response = JSON.parse(response.body)
    rescue Exception => e
      @google_oauth_response = {}
      puts "ERROR: Google auth: #{response.body} \n #{e} #{e.backtrace.join("\n")}"
    end
  end

  def get_user_info
    uri = URI GOOGLE_OAUTH_PATHS["USER_INFO"]
    response = FaradayConnections.get(uri.scheme + "://" + uri.host).get do |req|
      req.url "#{uri.path}?access_token=#{@google_oauth_response["access_token"]}"
    end
    JSON.parse(response.body)
  end

  def self.refresh_token(old_user)
    refresh_token = old_user.google_token.refresh_token
    request_params = {
      "client_id" => GOOGLE_CLIENT_ID,
      "client_secret" => GOOGLE_CLIENT_SECRET,
      "refresh_token" => refresh_token,
      "grant_type" => "refresh_token"
    }
    request_params = request_params.map { |key, value| "#{key}=#{value}" }.join("&")
    res = FaradayConnections.get(GOOGLE_OAUTH_HOST).post do |req|
      req.url OAUTH_EXCHANGE_PATH
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = request_params
    end
    begin
      response = JSON.parse(res.body)
      old_user.google_token.access_token = response["access_token"]
      expires = response["expires_in"] ? response["expires_in"].to_i : 0
      old_user.google_token.expires = Time.now.to_i + expires
      old_user.google_token.save
    rescue Exception => e
      puts "ERROR: refreshing token - #{e} #{e.backtrace.join("\n")}"
    end
  end

end
