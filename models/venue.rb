require File.join(File.dirname(File.dirname(__FILE__)), "lib", "dist_calc")

class Venue < Sequel::Model

  def after_create
    Resque.enqueue(VenueJobs, self.id)
  end

  def public_model(user_lat, user_long)
    distance = DistCalc.distance_formatted(lat, long, user_lat, user_long)
    {
      "yelp_id" => yelp_id,
      "foursquare_id" => foursquare_id,
      "address" => "#{address} - #{distance[:amount]} #{distance[:metric]}",
      "location" => { "coordinate" => { "latitude" => lat, "longitude" => long } },
      "yelp_rating" => yelp_rating,
      "foursquare_rating" => foursquare_rating
    }
  end
end
