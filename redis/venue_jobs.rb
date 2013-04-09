require "resque"
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "db")
require File.join(File.dirname(File.dirname(__FILE__)), "models", "all")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "foursquare_search")

class VenueJobs
  @queue = :venue

  def self.perform(venue_id)
    venue = Venue[:id => venue_id]
    if venue.lat.nil? || venue.long.nil?
      puts "ERROR: location not availabe"
      return
    end
    if venue.foursquare_id.nil?
      fs_search = FoursquareSearch.new(venue.name, venue.lat, venue.long, false, true)
      venue.update(:foursquare_id => fs_search.id, :foursquare_rating => fs_search.rating)
    elsif venue.yelp_id.nil?
      puts "yelp id is missing but foursquare is not"
      # shouldn't really get here
    else
      puts "everything is fine here!"
    end
  end
end