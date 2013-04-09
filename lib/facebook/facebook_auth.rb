require "faraday"
require "json"
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "envs")

class FacebookAuth

  attr_reader :facebook_oauth_response

  def initialize(code, error, redirect_path)
    puts "ERROR: facebook oauth failed - #{error}" unless error.nil?
    # TODO(noam): background this.
    # TODO(noam): Keep an open connection with facebook
    res = FaradayConnections.get("https://graph.facebook.com").get("/oauth/access_token" +
       "?client_id=#{FACEBOOK_APP_ID}" +
       "&redirect_uri=http://#{APP_URL + redirect_path}" +
       "&client_secret=#{FACEBOOK_SECRET}" +
       "&code=#{code}")
    if res.body.index("error").nil?
      @facebook_oauth_response = Rack::Utils.parse_nested_query(res.body).merge(:code => code)
    else
      puts "ERROR: requesting token from facebook: #{JSON.parse(res.body)["error"]}"
    end
  end

  def get_user_info
    response = FaradayConnections.get("https://graph.facebook.com").get("/me?" +
        "access_token=#{@facebook_oauth_response["access_token"]}")
    JSON.parse response.body
  end
end