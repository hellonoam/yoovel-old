require "faraday"
require "json"
require "cgi"
require "uri"
require "nokogiri"
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "envs")

class OpentableSearch

  attr_reader :party_size

  # Using mobile because its easier to parse
  RESERVATION_URL = "http://m.opentable.com/search/results"

  def initialize(restaurant_id, party_size = 2, future_date = nil, future_time = nil)
   # OT conventions are below
    reservation_params = {
      "SelectLocationSearchBox" => "",
      "SelectRestaurantSearchBox" => "",
      "Date" => CGI::escape(Time.new.getlocal("-08:00").strftime("%Y-%m-%d") + "T00:00:00"),
      # Look 1/2 hour into the future for a spot
      "TimeInvariantCulture" => "0001-01-01T#{CGI::escape((Time.new.getlocal("-08:00") + (60 * 60)).strftime('%H:%M:%S'))}",
      "PartySize" => 2,
      # This parameter doesn't seem to matter, since 33 is probably Bay Area but worked for a Texan Restaurant
      "MetroAreaID" => 33,
      "RegionID" => "",
      "Latitude" => "",
      "Longitude" => "",
      "RestaurantID" => "",
      "PartnerReferralID" => "",
      "ConfirmationNumber" => "",
      "ClientTimeStamp" => CGI::escape((Time.now.getlocal("-08:00") + 60*60).strftime("%Y-%m-%d %H:%M:%S").gsub(" ", "T")),
      "OfferConfirmNumber" => 0,
      "ChosenOfferId" => 0
    }
   @party_size = party_size || 2

    if restaurant_id.nil?
      return
    end

    reservation_params["RestaurantID"] = restaurant_id
    reservation_params["PartySize"] = party_size
    reservation_params["TimeInvariantCulture"] = future_time if future_time
    reservation_params["Date"] = future_date if future_date

    uri = URI "#{RESERVATION_URL}?#{reservation_params.map { |k, v| "#{k}=#{v}" }.join("&")}"
    @res = FaradayConnections.make_request_through_cache(uri, 5.minutes)
    if @res.status == 200
      @restaurant_booked_now = (@res.body.index("No tables") || @res.body.index("ulSlots").nil?) ? false : true
    elsif @res.status == 302
      @res = FaradayConnections.make_request_through_cache( URI(@res.headers["Location"]), 5.minutes)
      @restaurant_booked_now = (@res.body.index("No tables") || @res.body.index("ulSlots").nil?) ? false : true
    end
  end

  def get_available_slots
    available_times = []
    begin
      doc = Nokogiri::HTML(@res.body)
      doc.xpath("//ul[@id = 'ulSlots']/li/div/a").each do |node|
        available_times << node.text
      end
    rescue Exception => e
      puts "ERROR (opentable): Error parsing response from opentable for restaurant availability." +
              "#{e.message}."
    end
    available_times
  end

  def is_restaurant_available?
    @restaurant_booked_now
  end
end
