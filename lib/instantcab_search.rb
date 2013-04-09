require "lrucache"
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "transport_app_integration")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "faraday_connections")

class InstantcabSearch < TransportAppIntegration

  attr_reader :available_drivers, :closest_driver, :error

  INSTANTCAB_QUERY_URL = "http://www.instantcab.com/maps/service_pro_positions/?lat=:lat&lng=:long"

  def initialize(lat, long)
    @rank = 1
    @name = "InstantCab"
    @app_icon_name = "instantcab.jpg"
    @links = ["instantcab://", "https://itunes.apple.com/us/app/instantcab/id513651818?mt=8"]
    response = FaradayConnections.make_request(
        URI(INSTANTCAB_QUERY_URL.gsub(":lat", lat.to_s).gsub(":long", long.to_s)), true)
    begin
      @description = JSON.parse(response.body)["message"]
    rescue
      @error = true
      puts "ERROR (instantcab): couldn't get message from response"
    end
  end

end
