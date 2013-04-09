require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "transport_app_integration")
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "faraday_connections")
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "nextmuni")

class GoogleDirections < TransportAppIntegration

  attr_reader :description, :error

  URL = "https://maps.googleapis.com/maps/api/directions/json?sensor=true"

  # Destination and origin can either be an array [lat, long] or it can be a string which is the address of
  # the location. mode can be walking/driving/bicycling
  def initialize(destination, origin, mode = "transit")
    case(mode)
    when "transit"
      @rank = 4
      @price = "$2"
      @name = "Public Transport"
    when "bicycling"
      @rank = 6
      @price = "free"
      @name = "Bike"
    else
      @name = "Drive"
      @rank = 5
    end
    @app_icon_name = "googlemaps.jpg"
    origin = origin.is_a?(Array) ? origin.join(",") : origin.gsub(" ", "+")
    destination = destination.is_a?(Array) ? destination.join(",") : destination.gsub(" ", "+")
    @links = ["comgooglemaps://?saddr=#{origin}&daddr=#{destination}&directionsmode=#{mode}",
              "http://maps.apple.com/maps?saddr=#{origin}&daddr=#{destination}&directionsmode=#{mode}"]
    begin
      response = FaradayConnections.make_request_through_cache(
          URI("#{URL}&origin=#{origin}&destination=#{destination}&mode=#{mode}&departure_time=#{time}"),
          1.minutes)
      result = JSON.parse(response.body)
      @description = []
      nextmuni = nil
      puts "DEBUG: starting to calculate route!"
      if result["routes"].length == 0
        puts "DEBUG: no public transit routes found"
        @error = true
        return
      end
      route = result["routes"][0]
      legs = route["legs"]
      steps = legs[0]["steps"]
      duration = legs[0]["duration"]["text"]

      transit = select_transit(steps).map do |step|
        line = step["transit_details"]["line"]
        # NextMuni for the first leg of the public transit trip
        nextmuni ||= NextMuni.new(line["short_name"], line["vehicle"]["type"],
            step["transit_details"]["headsign"], step["transit_details"]["departure_stop"]["name"],
            step["transit_details"]["arrival_stop"]["name"])

        if line["vehicle"]["type"] == "SUBWAY"
          if line["agencies"] && line["agencies"][0] && line["agencies"][0]["url"] == "http://www.bart.gov/"
            vehicle = "Bart "
          else
             vehicle = "Subway "
           end
        end

        line["short_name"].nil? ? "#{vehicle}#{line["name"]}" : "#{vehicle}#{line["short_name"]}"
      end
      puts "DEBUG: finished calculating route"

      @error = true if transit.empty?
      transit_text = (transit.length > 1 ? "Lines: " : "Line: ") + transit.join(" > ")
      @description << "#{transit_text} - #{duration}"
      if nextmuni.error || nextmuni.eta.nil?
        @description << "Realtime data unavailable"
      else
        if transit[0].length < 18
          @description << "#{transit[0]} departs in "
        else
          @description << "#{transit[0][0..18]}... departs in "
        end
        @timer = true
        @seconds = nextmuni.eta
      end
    rescue Exception => e
      puts "ERROR: (google directions): couldn't parse response - #{e}"
      @error = true
    end
  end

  def format_eta
    if @seconds.to_i < 60
      "#{@seconds} seconds"
    else
      minutes = Integer(@seconds.to_i / 60)
      seconds = @seconds.to_i - (minutes * 60)
      "#{minutes} #{minutes > 1 ? "minutes" : "minute"} #{seconds} #{seconds > 1 ? "seconds" : "second" }"
    end
  end

  private

  def select_transit(steps)
    steps.select{ |step| step["travel_mode"] == "TRANSIT" }
  end

  # round up to the nearest ten seconds
  def time
    (1 + Time.now.to_i/10).ceil * 10
  end
end
