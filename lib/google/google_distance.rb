require "cgi"
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "faraday_connections")
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "transport_app_integration")

# https://developers.google.com/maps/documentation/distancematrix/
# Distance Matrix can use either imperial or metric system. However, this choice only affects the text field
# in the distance object (see above page for reference). There is also a values property under distance which
# is always in meters
class GoogleDistance < TransportAppIntegration

  attr_reader :kilometers, :miles, :duration, :duration_text, :error

  URL = "https://maps.googleapis.com/maps/api/distancematrix/json?sensor=true&units=imperial"

  # Destination and origin can either be an array [lat, long] or it can be a string which is the address of
  # the location. mode can be walking/driving/bicycling
  def initialize(destination, origin, mode = "driving")
    case(mode)
    when "walking"
      @rank = 7
      @price = "free"
      @name = "Walk"
    when "bicycling"
      @name = "Bike"
      @rank = 8
      @price = "free"
    else
      @name = "Drive"
      @rank = 9
    end
    @app_icon_name = "googlemaps.jpg"
    origin = origin.is_a?(Array) ? origin.join(",") : origin.gsub(" ", "+")
    destination = destination.is_a?(Array) ? destination.join(",") : destination.gsub(" ", "+")
    @links = ["comgooglemaps://?saddr=#{origin}&daddr=#{destination}&directionsmode=#{mode}",
              "http://maps.apple.com/maps?saddr=#{origin}&daddr=#{destination}&directionsmode=#{mode}"]
    begin
      response = FaradayConnections.make_request_through_cache(
          URI("#{URL}&origins=#{CGI::escape origin}&destinations=#{CGI::escape destination}&mode=#{mode}"))
      result = JSON.parse(response.body)
      @kilometers = result["rows"][0]["elements"][0]["distance"]["value"].to_f / 1000
      @miles = @kilometers/1.60934
      # Returned in minutes which is what sidecar needs
      @duration = result["rows"][0]["elements"][0]["duration"]["value"] / 60
      @duration_text = result["rows"][0]["elements"][0]["duration"]["text"]
      @description = "#{duration_text} #{mode}"
    rescue
      @error = true
      puts "ERROR (google distance): error parsing data"
    end
  end

end
