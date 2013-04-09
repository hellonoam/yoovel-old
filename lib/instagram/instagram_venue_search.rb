require "faraday"
require "json"
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "envs")

class InstagramVenueSearch

  attr_reader :images, :thumbnails, :place_id

  MIN_NUMBER_OF_IMAGES_TO_GET = 5
  MAX_NEXT_PAGE_ITERATIONS = 2

  INSTAGRAM_OAUTH_PATHS = {
    :location_search => "https://api.instagram.com/v1/locations/search?foursquare_v2_id=:foursquare_id",
    :location_images => "https://api.instagram.com/v1/locations/:location_id/media/recent?"
  }

  def initialize(foursquare_id)
    @foursquare_id = foursquare_id
    @@access_token ||= DB[:instagram_tokens].first[:access_token]
    @images = []
    @thumbnails = []
    get_images_for_venue
  end


  def get_images_for_venue()
    begin
      search_uri = "#{INSTAGRAM_OAUTH_PATHS[:location_search]}&access_token=#{@@access_token}"
      search_uri.gsub!(/:foursquare_id/, @foursquare_id)
      search_uri = URI search_uri
      response = FaradayConnections.make_request_through_cache(search_uri)
      json_response = JSON.parse(response.body)
      @place_id = json_response["data"][0]["id"]
      location_url = "#{INSTAGRAM_OAUTH_PATHS[:location_images]}&access_token=#{@@access_token}"
      location_url.gsub!(/:location_id/, @place_id)
      MAX_NEXT_PAGE_ITERATIONS.times do
        break unless !location_url.nil? && location_url != "" && @images.length < MIN_NUMBER_OF_IMAGES_TO_GET
        response = FaradayConnections.make_request_through_cache(URI location_url)
        json_response = JSON.parse(response.body)
        good_images = json_response["data"].reject { |image| image["likes"]["count"] < 10 }
        @images.concat(good_images.map { |image| image["images"]["low_resolution"]["url"] })
        @thumbnails.concat(good_images.map { |image| image["images"]["thumbnail"]["url"] })
        location_url = json_response["pagination"]["next_url"]
      end
    rescue Exception => e
      puts "ERROR (instagram images venue search) - something went wrong #{e.message}"
    end
  end
  
end