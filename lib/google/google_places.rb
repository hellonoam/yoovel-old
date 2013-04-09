require "oauth"
require "lrucache"
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "faraday_connections")

class GooglePlaces

  attr_reader :hours_of_operation

  API_KEY = "AIzaSyBijKS-O1be8REf60Jo84WYi2O-1yFQgR8"

  DEFAULT_TTL = 3.hours

  SEARCH_PATH = "nearbysearch/json?location=:latlong&radius=1000&name=:name&sensor=true&key=:key"
  DETAILS_PATH = "details/json?reference=:reference&sensor=true&key=:key"
  HOST = "https://maps.googleapis.com/maps/api/place/"

  @search_results = {}

  def initialize(query, lat, long)
    @query, @lat, @long = query, lat, long

    begin
      uri = URI(HOST + SEARCH_PATH.gsub(/:latlong/, "#{@lat},#{@long}").gsub(/:name/,
            @query).gsub(/:key/, API_KEY))
      @search_results  = make_request(uri)["results"]
      unless @search_results.empty?
        reference_id = @search_results.first["reference"]
        uri = URI(HOST + DETAILS_PATH.gsub(/:reference/, reference_id).gsub(/:key/, API_KEY))
        @search_results = make_request(uri)["result"]
        unless @search_results.empty?
          @hours_of_operation = @search_results["opening_hours"]
        end
      end
    rescue Exception => e
      puts "ERROR (google places search): couldn't parse json response #{e.message}"
    end
  end

  def make_request(uri) 
    JSON.parse(FaradayConnections.make_request_through_cache(uri).body) rescue {}
  end

  def cache_key
    "#{@query},#{@lat},#{@long}"
  end

end
