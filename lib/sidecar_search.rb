require "lrucache"
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "transport_app_integration")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "faraday_connections")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "google", "google_distance")

class SidecarSearch < TransportAppIntegration

  attr_reader :available_drivers, :closest_driver, :error

  PRICES = { :base => 0, :per_min => 0.5, :per_mile => 1.7, :min => 8 }

  def initialize(lat, long, dest_lat, dest_long)
    @name  = "Sidecar"
    @rank = 2
    @app_icon_name = "sidecar.jpg"
    # change the custom url to that when sidecar fixed their bug
    # "sidecar://source=#{lat},#{long}&destination=#{dest_lat},#{dest_long}&client=corral"
    @links = ["sidecar://",
              "https://itunes.apple.com/us/app/sidecar-ride/id524617679"]
    @lat, @long = lat, long
    sidecar_query_url = URI "https://app.side.cr/vehicle/getClosestDrivers" + "/#{@lat}/#{@long}"
    response = FaradayConnections.get(sidecar_query_url.scheme + "://" + sidecar_query_url.host).get do |req|
      req.url sidecar_query_url
    end
    begin
      drivers = JSON.parse(response.body)["drivers"]
      @available_drivers = drivers.length
      @closest_driver = calculate_closest_driver(drivers)
      @description = "#{@available_drivers} drivers available, nearest #{@closest_driver} away"
      @description = "No drivers available" if @available_drivers == 0
    rescue
      @error = true
      puts "ERROR (sidecar): couldn't get drivers from response"
    end
  end

  def calculate_closest_driver(drivers)
    return nil if drivers.empty?
    closest = drivers.min_by { |d| d["dist"] }
    # Since we have closest (in miles) available, could just use ~5 min/mile as an estimate
    GoogleDistance.new([closest["lat"], closest["lng"]], [@lat, @long]).duration_text
  end

  # TODO(snir): Regression analysis on their fare calculation
  def get_fare_calculation(time, distance, dest_lat, dest_long)
    return if @error
    # Seems like the sidecar fare calculation route doesn't actually care about your dest lat/long
    # Can use the same location as source lat/long with appropriate distance/time metrics, and responds
    # accurately
    fare_url = "https://app.side.cr/fare/calculateFareLatLng/#{distance}/#{time}/" +
                    "#{@lat}/#{@long}/#{dest_lat}/#{dest_long}/-7.000000/0"
    response = FaradayConnections.make_request_through_cache(URI(fare_url))
    begin
      @price = "$#{JSON.parse(response.body)["fare"]}"
      return @price
    rescue
      puts "ERROR (sidecar): couldn't get proper response from fare route: #{response.body}"
      nil
    end
  end

end
