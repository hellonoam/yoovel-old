require "lrucache"
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "transport_app_integration")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "faraday_connections")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "dist_calc")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "google", "google_distance")

class UberSearch < TransportAppIntegration

  attr_reader :error

  # Uber fares found on uber.com
  PRICES = {
    :UBERX => { :base => 5.75, :per_mile => 3.75, :per_min => 0.85, :min => 10 },
    :BLACK => { :base => 7.00, :per_mile => 4.00, :per_min => 1.05, :min => 15 },
    :SUV   => { :base => 15.0, :per_mile => 5.00, :per_min => 1.35, :min => 25 },
    :TAXI  => { :base => 4.50, :per_mile => 2.75, :per_min => 0.55, :min => 0  }
  }

  REQUEST_BODY = {
    "deviceOS" => "6.1.3",
    "device" => "iphone",
    "language" => "en",
    "longitude" => "",
    "latitude" => "",
    "version" => "2.1.4",
    "app" => "client",
    "deviceId" => "30:F7:C5:86:94:91",
    "messageType" => "PingClient",
    "deviceModel" => "iPhone5,1",
    "token" => "e5229a0dc74649f24c5e97b5cc598b18"
  }

  def initialize(lat, long)
    @name  = "Uber"
    @rank = 3
    @app_icon_name = "uber.jpg"
    @links = ["uber://", "https://itunes.apple.com/us/app/uber/id368677368"]
    REQUEST_BODY["longitude"] = long
    REQUEST_BODY["latitude"] = lat
    response = FaradayConnections.post(URI(uber_url), REQUEST_BODY.to_json, 10.seconds)
    begin
      body = JSON.parse(response.body)
      near_by = body["nearbyVehicles"]
      if near_by.nil?
        error_occurred
        return
      end
      vehicle_views = body["city"]["vehicleViews"]
      all_vehicles_available = vehicle_views.map { |id, vehicle_obj| [id, vehicle_obj["description"]] }
      @types = {}
      all_vehicles_available.each do |id, name|
        @types[id] = {
          :name => name,
          :available_drivers => (near_by[id.to_s]["vehiclePaths"] || []).length,
          :closest_driver => near_by[id.to_s]["minEta"]
        }
      end
    rescue
      error_occurred
    end
  end

  def error_occurred
    puts "ERROR (uber): couldn't parse response"
    @error = true
  end

  # duration in mins, distance in miles - in order to calculate the fare
  def etas(duration, distance)
    description = []
    add_prices_to_types(duration, distance) if @price.nil?
    @types.each do |_, type_hash|
      type_desc = " #{type_hash[:name].capitalize}"
      if type_hash[:available_drivers] == 0
        type_desc += " No drivers available"
      else
        type_desc += " - #{type_hash[:available_drivers]} drivers" if type_hash[:available_drivers]
        type_desc += " - #{type_hash[:closest_driver]}min " if type_hash[:closest_driver]
      end
      type_desc += " - $#{type_hash[:price].round(0)}" if type_hash[:price]
      description << type_desc
    end
    # description << " email service@uber.com for live eta"
    description
  end

  AVERAGE_METERS_PER_MIN_SPEED = 40*1000/60

  def add_prices_to_types(duration, distance)
    # return if @error
    if @error && @types.nil?
      @types = [ [1, :name => "SUV"],   [2, :name => "Black Car"],
                 [3, :name => "UberX"], [4, :name => "TAXI"] ]
      @error = false
    end
    @types.each do |id, type_hash|
      price = PRICES[type_hash[:name].split(" ").first.upcase.to_sym]
      if price.nil?
        puts "Uber has added a new category; need to add it to our price list"
        next
      end
      travel_price_old = [price[:per_mile] * distance, price[:per_min] * duration].max
      travel_price = price[:per_mile] * distance +
                     price[:per_min] * (duration/60 - distance/AVERAGE_METERS_PER_MIN_SPEED)
      type_hash[:price] = [(price[:base] + travel_price * 1.05), price[:min]].max.round(0)
    end
    prices = @types.map { |_, type_hash| type_hash[:price].to_i unless type_hash[:price].nil?}
    # Need to delete the nils from the previous map if we didnt have pricing information
    prices.delete nil
    @price = "$#{prices.min} - $#{prices.max}"
    @description = etas(duration, distance)
  end

  def uber_url
    # TODO(noam): maybe change cn9 to be cnX where X is 1/2/3/4/9/10/11... since those all do the same
    "https://cn9.uber.com"
  end

end
