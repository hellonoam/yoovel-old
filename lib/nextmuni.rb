require File.join(File.dirname(File.dirname(__FILE__)), "lib", "faraday_connections")
require "nokogiri"

class NextMuni

  attr_reader :eta, :error

  # routeList, routeConfig and predictions are the three commands that need to be issued per bus
  # need to append an &s=:stopTag for predictions requests and &r=:routeNumber for routeConfig and predictions
  MUNI_URL = "http://webservices.nextbus.com/service/publicXMLFeed?command=:command&a=sf-muni"
  BART_URL = "http://api.bart.gov/api/etd.aspx?cmd=etd&orig=:abbr&key=:key"
  BART_API_KEY = "E9KH-PT6K-U7TT-5AIH"

  def initialize(shortname, vehicle_type, direction, busstop, endstop)
    @cable_car = false
    @vehicle_type = vehicle_type
    @direction = direction
    @busstop = busstop
    @endstop = endstop
    @shortname = shortname
    sanitizeBusstop
    if @vehicle_type == "CABLE_CAR"
      @cable_car = true
      @shortname = shortname.gsub("-", "/")
    end
    # Take into account agency type so that we don't go through this logic path for non-SF cities
    # Probably just need to include another parameter
    begin
      if @vehicle_type == "SUBWAY"
        bart_abbreviations = JSON.parse(File.read("./lib/bart.json"))
        get_bart_eta(bart_abbreviations)
      else
        get_muni_eta
        puts "DEBUG: finished getting NEXTMUNI eta"
      end
    rescue Exception => e
      @eta = nil
      @error = true
      puts "ERROR (nextmuni): couldn't retrieve route information " + e.message
    end
  end

  # Google Maps inclusion of names that confuse NextBus
  def sanitizeBusstop
    [@busstop, @endstop].each do |stop|
      stop = stop.split(/[ \/]/)
      stop.delete("Metro")
      stop.delete("Inbound")
      stop.delete("Outbound")
      stop = stop.join(" ")
    end
  end

  def get_bart_eta(bart_abbr)
    destination_abbr = station_abbreviation(bart_abbr, @direction)
    start_abbr = station_abbreviation(bart_abbr, @busstop)
    bart_uri = URI(BART_URL.gsub(":key", BART_API_KEY).gsub(":abbr", start_abbr))
    bart_response = FaradayConnections.get(bart_uri.scheme + "://" + bart_uri.host).get do |req|
      req.url bart_uri
    end
    xml = Nokogiri::XML bart_response.body
    xml.xpath("//etd").each do |etd|
      if destination_abbr.upcase == etd.xpath("abbreviation")[0].text.upcase
        @eta = etd.xpath("estimate").first.xpath("minutes").first.text
        @eta = Integer(@eta) * 60
      end
    end
  end

  def station_abbreviation(bart_abbr, fullname)
    bart_abbr.each do |station, abbr|
      if station.index(fullname)
        return abbr
      end
    end
    nil
  end

  def get_muni_eta
    route_list_url = MUNI_URL.gsub(":command", "routeList")
    response = FaradayConnections.make_request_through_cache(URI(route_list_url))
    xml = Nokogiri::XML response.body
    xml.xpath("//route").each do |route|
      if route["tag"] == @shortname || (@cable_car && route["title"].upcase.index(@shortname.upcase))
        stop_id = get_route_config(route["tag"])
        direction_tag = get_direction_tag(stop_id, route["tag"])
        get_eta(route["tag"], stop_id, direction_tag)
      end
    end
  end

  def get_direction_tag(stop_id, route_id)
    return nil if stop_id.nil?
    route_config_url = MUNI_URL.gsub(":command", "routeConfig") + "&r=" + route_id
    route_response = FaradayConnections.make_request_through_cache(URI(route_config_url))
    xml = Nokogiri::XML route_response.body
    xml.xpath("//direction").each do |direction|
      direction.xpath("stop").each do |stop|
        if stop["tag"] == stop_id
          return direction["tag"]
        end
      end
    end
    nil
  end

  def get_route_config(route_id)
    possible_stops = []
    route_config_url = MUNI_URL.gsub(":command", "routeConfig") + "&r=" + route_id
    route_response = FaradayConnections.make_request_through_cache(URI(route_config_url))
    outbound = @direction.upcase.index("OUTBOUND")
    inbound = @direction.upcase.index("INBOUND")
    xml = Nokogiri::XML route_response.body
    xml.xpath("//direction").each do |direction|
      same_direction =  direction["title"].upcase.index(@direction.upcase) ||
                        (outbound && direction["name"].upcase.index("OUTBOUND")) ||
                          (inbound && direction["name"].upcase.index("INBOUND"))
      if same_direction
        direction.xpath("stop").each do |stop|
          possible_stops << stop["tag"]
        end
      end
    end
    # Bus headsigns aren't always consistent with one of their directions
    # In these cases we need to actually understand route data and be able to suggest
    # which stop is the departure stop, given that we're going in the direction of the 
    # arrival stop
    if possible_stops.empty?
      start_found = false
      stop_tag = nil
      xml.xpath('//route/stop').each do |stop|
        if stop["title"].upcase.index(@busstop.upcase) && !start_found
          stop_tag = stop["tag"] 
          start_found = true
        elsif stop["title"].upcase.index(@busstop.upcase) && start_found
          puts "Uh oh, we didnt find the destination stop before finding the starting stop again"
          break
        end
        if start_found && stop_inclusion(stop["title"].upcase, @endstop.upcase)
          return stop_tag
        end
      end
    end
    xml.xpath('//route/stop').each do |stop|
      if possible_stops.include?(stop["tag"]) && stop_inclusion(stop["title"].upcase, @busstop.upcase)
        return stop["tag"]
      end
    end
    return nil
  end

  def stop_inclusion(json_stop, busstop)
    json_arr = json_stop.split("&")
    busstop_arr = busstop.split("&")
    json_arr.each_index do |index|
      return false if busstop_arr[index].nil?
      if json_arr[index].strip.index(busstop_arr[index].strip).nil? &&
        busstop_arr[index].strip.index(json_arr[index].strip).nil?
        return false
      end
    end
    true
  end

  def get_eta(route_number, stop_id, direction_tag)
    eta_url = MUNI_URL.gsub(":command", "predictions") + "&r=" + route_number + "&s=" + stop_id
    eta_url = URI eta_url
    eta_response = FaradayConnections.get(eta_url.scheme + "://" + eta_url.host).get do |req|
      req.url eta_url
    end
    xml = Nokogiri::XML eta_response.body
    # Only returning one for now; might want more in the future
    backup_eta = nil
    xml.xpath('//prediction').each do |prediction|
      if direction_tag && direction_tag == prediction["dirTag"]
        @eta = prediction["seconds"]
        break
      end
      backup_eta = prediction["seconds"] if backup_eta.nil?
    end
    @eta ||= backup_eta
  end

end
