require "faraday"
require "json"
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "envs")

class TwitterSearch

  attr_reader :username

  def initialize(twitter_page)
    #Sample response from fliptop: http://twitter.com/andrewmeyer1
    @username = twitter_page.rpartition("/").last
  end

  def last_tweets(page_count = 10)
    res = FaradayConnections.make_request_through_cache(URI("https://api.twitter.com/1/statuses" +
        "/user_timeline.json?screen_name=#{username}&count=#{page_count}"), 1.hour, false)
    tweets = JSON.parse(res.body) rescue []
    return [] if tweets.empty? || (tweets.is_a?(Hash) && tweets["error"])
    tweets.map { |tweet| tweet["text"] }
  end
end
