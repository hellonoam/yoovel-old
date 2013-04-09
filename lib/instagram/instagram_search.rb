require "faraday"
require "json"
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "envs")

class InstagramSearch

  attr_reader :images, :thumbnails, :username

  INSTAGRAM_OAUTH_PATHS = {
    "SEARCH" => "https://api.instagram.com/v1/users/search?q=:query",
    "RECENT_MEDIA" => "https://api.instagram.com/v1/users/:user_id/media/recent",
    "RELATIONSHIP" => "https://api.instagram.com/v1/users/:user_id/relationship"
  }

  def initialize(user, query = nil)
    return if user.nil?
    @query = query
    @token = user.instagram_token
    @images = []
    @thumbnails = []
    perform unless @query.nil?
  end

  def authenticated?
    !@token.nil?
  end

  def perform
    return if @token.nil?
    begin
      get_media_for_user(@query)
    rescue Exception => e
      puts "ERROR - failed to get instagram details for #{@query}. #{e}"
    end
  end

  def get_media_for_user(query)
    # TODO(noam): Add instagram cache for query + user.id
    search_uri = "#{INSTAGRAM_OAUTH_PATHS["SEARCH"]}&access_token=#{@token.access_token}".gsub(/:query/,
        CGI::escape(@query))
    search_uri = URI(search_uri)
    response = FaradayConnections.make_request_through_cache(search_uri)
    json_response = JSON.parse(response.body) rescue { "data" => [] }
    users = []
    usernames = {}
    json_response["data"].each do |single_contact|
      users << single_contact["id"]
      usernames[single_contact["id"]] = single_contact["username"]
    end

    return if users.empty?

    # Consider all IDS for matching searches
    id_to_fetch = nil
    rel_uri = "#{INSTAGRAM_OAUTH_PATHS["RELATIONSHIP"]}?access_token=#{@token.access_token}"
    EM::Synchrony::FiberIterator.new(users, users.length).each do |user_id|
      rel_uri_stubbed = URI(rel_uri.gsub(/:user_id/, user_id))
      rel_response = FaradayConnections.make_request_through_cache(rel_uri_stubbed)
      json_rel_response = JSON.parse(rel_response.body)
      if json_rel_response["data"]["outgoing_status"] != "none"
        id_to_fetch = user_id
      end
    end

    id_to_fetch = users.first if users.length == 1
    return if id_to_fetch.nil?

    @username = usernames[id_to_fetch]

    media_uri = URI("#{INSTAGRAM_OAUTH_PATHS["RECENT_MEDIA"].gsub(/:user_id/, id_to_fetch)}?" +
      "access_token=#{@token.access_token}")
    media_response = FaradayConnections.make_request_through_cache(media_uri, 1.hours)
    json_media_response = JSON.parse(media_response.body)
    if json_media_response["data"]
      json_media_response["data"].each do |image|
        @images << image["images"]["low_resolution"]["url"]
        @thumbnails << image["images"]["thumbnail"]["url"]
      end
    end
  end
end
