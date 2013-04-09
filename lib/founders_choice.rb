require "lrucache"
require "json"
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "faraday_connections")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "yelp_search")

# Placeholder class. If we see this category get selected, we should consider actually buildilng
# an API out for SFEater
class FoundersChoice

  def initialize(lat, long)
    @lat, @long = lat, long
    @sf_lat = 37.7829
    @sf_long = -122.4084
    yelp_ids = ["local-mission-eatery", "burma-superstar", "limon-rotisserie-san-francisco-3",
    "don-pistos-san-francisco-2", "wise-sons-delicatessen", "chez-maman", "sunflower-potrero-hill",
    "allegro-romano", "super-duper-burgers-san-francisco-5", "a-16", "farina-focaccia-and-cucina-italiana",
    "21st-amendment-brewery"]
    @@founders_venue_data ||= get_top_restaurants(yelp_ids)
  end

  def recommendations
    @@founders_venue_data
  end

  def get_top_restaurants(yelp_ids)
    yelp_ids = prune_yelp_ids(yelp_ids)
    retrieve_venue_data(yelp_ids)
  end

  def prune_yelp_ids(yelp_ids)
    yelp_ids.map { |id| id.index("san-francisco") ? id : id + "-san-francisco" }
  end

  def retrieve_venue_data(yelp_ids)
    venue_data = {}
    begin
      EM::Synchrony::FiberIterator.new(yelp_ids, [yelp_ids.length, 5].min).each do |one_yelp_search|
        v = Venue[:yelp_id => one_yelp_search]
        if v.nil?
          yelp_response = YelpSearch.new(one_yelp_search, @sf_lat, @sf_long, 1, true, false)
          name = yelp_response.search_results.keys.first
          venue_data[name] = yelp_response.search_results[name]
        else
          venue_data[v.name] = [v.public_model(@lat, @long)]
        end
      end
    rescue Exception => e
      puts "ERROR (founders' choice): Error with founder choice results: #{e.message}"
    end
    venue_data
  end
end
