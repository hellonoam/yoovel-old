require "faraday"
require "cgi"
require "json"
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "envs")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "faraday_connections")

class FoursquareSearch

  # TODO: get the following: image - seems to be broken

  attr_reader :id, :name, :categories, :menu, :address, :address2, :cross_street, :search_result,
              :reservation_link, :tips, :phone_number, :website, :rating, :opentable_id

  FOURSQUARE_ENDPOINTS = {
    "VENUE_SEARCH_BY_NAME" => "https://api.foursquare.com/v2/venues/search?query=:query&limit=:li&ll=:ll&" +
            "client_id=:client_id&client_secret=:client_secret&v=:v",
    "SINGLE_VENUE_WITH_ID" => "https://api.foursquare.com/v2/venues/:id?v=:v&client_id=:client_id&" +
            "client_secret=:client_secret",
    "VENUE_SEARCH" => "https://api.foursquare.com/v2/venues/search?limit=10&ll=:ll&query=:query&" +
            "v=:v&client_id=:client_id&client_secret=:client_secret",
    "CATEGORY_MAP" => "https://api.foursquare.com/v2/venues/categories?v=:v&client_id=:client_id&" +
            "client_secret=:client_secret"
  }

  # Foursquare categories of interest to our app
  CATEGORIES_OF_INTEREST = ["Food", "Nightlife Spot", "Arts & Entertainment"]

  def initialize(query, latitude, longitude, id_query = true, single_venue_by_name = false)
    # TODO: this @@ doesn't work with resque tasks so better if we just hard code it somewhere.
    @@categories ||= get_foursquare_categories
    if id_query
      display_single_venue(query, latitude, longitude)
    elsif single_venue_by_name
      id = get_id_for_venue_name(query, latitude, longitude)
      display_single_venue(id, latitude, longitude)
    else
      @search_result = search_foursquare(query, latitude, longitude)
    end
  end

  def get_foursquare_categories
    uri = URI(get_request_with_fields(FOURSQUARE_ENDPOINTS["CATEGORY_MAP"]))
    all_categories = make_request(uri)["response"]["categories"]
    CATEGORIES_OF_INTEREST.map { |int_cat| all_categories.detect{ |category| category["name"] == int_cat } }
  end

  def get_id_for_venue_name(venue_name, latitude, longitude)
    venue_name = URI.escape(venue_name)
    begin
      uri = URI(get_request_with_fields(FOURSQUARE_ENDPOINTS["VENUE_SEARCH_BY_NAME"]).gsub(/:query/,
            venue_name).gsub(/:ll/, "#{latitude},#{longitude}").gsub(/:li/, "3"))
      all_venues = make_request(uri)["response"]["venues"]
      rest_venues = all_venues.select { |venue| is_venue_a_restaurant?(venue) }
      return rest_venues.length > 0 ? rest_venues.first["id"] : all_venues.first["id"]
    rescue Exception => e
      puts "ERROR (foursquare search) - error when retrieving a single venue by name. #{e}"
    end
  end

  def search_foursquare(query, latitude, longitude)
    # foursqaure returns an error if the length of the query is less than 3
    return {} if query.length < 3
    query = URI.escape(query)
    uri = URI(get_request_with_fields(FOURSQUARE_ENDPOINTS["VENUE_SEARCH"]).gsub(/:query/, query).gsub(
            /:ll/, "#{latitude},#{longitude}"))
    search_results(make_request(uri), latitude, longitude)
  end

  def display_single_venue(id, latitude, longitude)
    begin
      uri = URI(get_request_with_fields(FOURSQUARE_ENDPOINTS["SINGLE_VENUE_WITH_ID"]).gsub(
        /:ll/, "#{latitude},#{longitude}").gsub(/:id/, id))
      venue = make_request(uri)["response"]["venue"]
      @id, @name, @rating = id, venue["name"], venue["rating"]
      @reservation_link = venue["reservations"]["url"] if venue["reservations"]
      @opentable_id = extract_id_from_reservation_link(@reservation_link) if @reservation_link
      @phone_number = venue["contact"]["phone"] if venue["contact"]
      @website = venue["url"]
      @categories = parse_categories(venue["categories"])
      @menu = venue["menu"]["mobileUrl"] if venue["menu"]
      @city = venue["location"]["city"]
      @address = venue["location"]["address"]
      @address2 = "#{venue["location"]["city"]} #{venue["location"]["state"]} " +
                  "#{venue["location"]["postalCode"]}"
      @cross_street = venue["location"]["crossStreet"]
      @tips = parse_tips(venue["tips"])
      ""
    rescue Exception => e
      puts "ERROR (foursquare search) - exception: #{e}"
    end
  end

  def full_address
    "#{@address} #{@address2}"
  end

  def display_address
    "#{@address} #{@city}"
  end

  def extract_id_from_reservation_link(reservation_link)
    query_strings = (URI reservation_link).query.split("&")
    query_strings.each do |query_string|
      if query_string.upcase.index("RID") == 0
        return query_string.split("=").last
      end
    end
    # Conceivably no OT RID. Maybe because of changes to their API, for example
    nil
  end

  def parse_tips(tips_array)
    tips = []
    tips_array["groups"].each do |group|
      group["items"].each do |tip|
        tips << tip["text"]
      end
    end
    tips
  end

  def parse_categories(category_array)
    categories = []
    category_array.each do |category|
      if category["primary"]
        categories.insert(0, category["shortName"])
      else
        categories << category["shortName"]
      end
    end
    categories
  end

  def make_request(uri)
    JSON.parse(FaradayConnections.make_request_through_cache(uri).body) rescue {}
  end

  def search_results(json_search_response, lat, long)
    result_set = {}
    if json_search_response["response"].nil? || json_search_response["response"]["venues"].nil?
      return result_set
    end
    json_search_response["response"]["venues"].each do |minivenue|
      if !is_venue_a_restaurant?(minivenue) ||
        (minivenue["stats"] && minivenue["stats"]["checkinsCount"] < 100)
        next
      end
      name = minivenue["name"]
      result_set[name] ||= []
      rest_lat, rest_long = minivenue["location"]["lat"], minivenue["location"]["lng"]
      distance = DistCalc.distance_formatted(rest_lat, rest_long, lat, long)

      v = Venue[:foursquare_id => minivenue["id"]]
      if v
        result_set[name].push(v.public_model(lat, long))
        next
      end

      # TODO(noam): consider moving this somehow to venue.rb
      address = "#{minivenue["location"]["address"]} #{minivenue["location"]["city"]}"
      address += " - #{distance[:amount]} #{distance[:metric]}"
      location = { "coordinate" => { "latitude" => rest_lat, "longitude" => rest_long } }
      single_result = { "foursquare_id" => minivenue["id"], "address" => address, "location" => location }

      result_set[name].push(single_result)
    end
    Hash[result_set.sort]
  end

  def is_venue_a_restaurant?(minivenue)
    minivenue["categories"].each do |one_category_for_venue|
      @@categories.each do |restaurant_or_bar|
        cat_name = one_category_for_venue["id"]
        return true if restaurant_or_bar["categories"].detect { |category| category["id"] == cat_name }
      end
    end
    return false
  end

  def get_request_with_fields(request)
    request.gsub(/:v/, Time.now.strftime("%Y%m%d")).gsub(
        /:client_id/, FOURSQUARE_CLIENT_ID).gsub(/:client_secret/, FOURSQUARE_CLIENT_SECRET)
  end
end
