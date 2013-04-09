require "faraday"
require "json"
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "envs")
require "lrucache"

class FliptopSearch

  # TODO(noam): marge results from different emails

  # Sets an array of JSON objects in string form for the emails passed in
  # For those emails that nothing viable is returned from fliptop,
  # we simply ommit them from the result set
  def initialize(emails)
    return if emails.nil? || emails.empty?
    fliptop_results_for_user = []
    emails = emails.split(",") unless emails.is_a? Array
    emails.each do |email|
      res = FaradayConnections.make_request_through_cache(URI "http://api.fliptop.com/beta/person?" +
          "email=#{email}&api_key=#{FLIPTOP_KEY}")
      begin
        json_response = JSON.parse(res.body)
      rescue
        next
      end
      if json_response["name"]
        fliptop_results_for_user << json_response
      end
    end
    @result = fliptop_results_for_user
  end

  def twitter_username(index = 0)
    @result.each do |result|
      email = result["memberships"]["twitter"] if result && result["memberships"]
      return email unless email.nil?
    end
    nil
  end
end
