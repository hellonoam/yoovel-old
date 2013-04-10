class Place
  attr_reader :name, :categories, :menu, :phone_number, :website, :image, :apps,
              :available, :hours_available

  def initialize(place_hash, format = "html")
    taximojo = place_hash[:taximojo]
    foursquare = place_hash[:foursquare]
    yelp = place_hash[:yelp]
    lyft = place_hash[:lyft]
    uber = place_hash[:uber]
    sidecar = place_hash[:sidecar]
    rest_lat, rest_long = place_hash[:rest_location]
    opentable = place_hash[:opentable]
    distance_driving = place_hash[:distance_driving]
    distance_walking = place_hash[:distance_walking]
    distance_cycling = place_hash[:distance_cycling]
    public_transport = place_hash[:public_transport]
    instagram = place_hash[:instagram]
    @available = opentable.is_restaurant_available?
    @hours_available = opentable.get_available_slots.join(", ") if @available
    @image = yelp.photo || "/images/delfina.jpeg"
    @name = foursquare.name
    @categories = foursquare.categories || []
    @menu = foursquare.menu
    @phone_number = foursquare.phone_number || yelp.phone_number
    @website = foursquare.website
    @images = instagram.images if instagram

    address, cross_street = "#{foursquare.address} #{foursquare.address2}", foursquare.cross_street

    @apps = []
    unless address.to_s.empty?
      sub_title = [address]
      durations = []
      durations << "driving: #{distance_driving.duration_text}" unless distance_driving.error
      durations << "walking: #{distance_walking.duration_text}" unless distance_walking.error
      durations << "cycling: #{distance_cycling.duration_text}" unless distance_cycling.error
      sub_title << "Durations - #{durations.join(", ")}" unless durations.empty?
      unless public_transport.error
        sub_title << "Public Transport: #{public_transport.description.join("\n")} #{public_transport.format_eta}"
      end
      sub_title.map! { |line| "<p>#{line}</p>" } if format == "html"
      @apps << { :rank => 1, :name => "maps", :icon => "googlemaps.jpg", :title => "Address",
          :sub_title => sub_title.join("\n"),
          :link => ["comgooglemaps://?q=#{address.strip.gsub(" ", "+")}",
                    "http://maps.apple.com/maps?q=#{address.strip.gsub(" ", "+")}"] }
    end

    sub_title = ["Click to open venue page"]
    if foursquare.tips && foursquare.tips.first
      sub_title = foursquare.tips.slice(0..1)
    else
      sub_title = ["No tips here, be the first to tip"]
    end
    sub_title.map! { |line| "<p>#{line}</p>" } if format == "html"
    foursquare_title = "Foursquare"
    foursquare_title += " - Rated #{foursquare.rating} / 10" if foursquare.rating
    @apps << { :rank => 3, :name => "foursquare", :icon => "foursquare.jpg", :title => foursquare_title,
        :sub_title => sub_title.join("\n"), :link =>
        ["foursquare://venues/#{foursquare.id}", "https://itunes.apple.com/us/app/foursquare/id306934924"] }

    if foursquare.reservation_link
      if @available.nil?
        sub_title = ["Corral has no availability information; please call the venue"]
      elsif @available
        availability_verb = @hours_available.length > 1 ? "availabilities are" : "availability is"
        sub_title = ["OpenTable has availability for your party of size #{opentable.party_size}. " +
                        "Closest #{availability_verb} #{@hours_available}", 
                     "Click to reserve a table"]
      else
        sub_title = ["OpenTable has no availablility within the next 2 hours for your party " +
                        "size of #{opentable.party_size}"]
      end
      sub_title.map! { |line| "<p>#{line}</p>" } if format == "html"
      @apps << { :rank => 4, :name => "opentable", :icon => "opentable.jpg", :title => "OpenTable",
          :sub_title => sub_title.join("\n"), :link => [foursquare.reservation_link] }
    end

    # Maybe use yelp.rating_photo
    title = "Yelp"
    title += " - Rated #{yelp.rating} / 5" unless yelp.rating.to_s.empty?
    if yelp.id && yelp.rating
      @apps << { :rank => 2, :icon => "yelp.jpg", :title => "Yelp - Rated #{yelp.rating} / 5",
          :name => "yelp", :sub_title => yelp.review,
          :link => ["yelp4:///biz/#{yelp.id}",
                    "https://itunes.apple.com/us/app/yelp/id284910350"] }
    end

    if instagram && instagram.place_id && instagram.thumbnails.length > 0
      @apps << { :rank => 5, :icon => "instagram.jpg", :title => "instagram images", :name => "instagram",
          :sub_title => "click to see images on instagram, update the app to see a preview of the images",
          :thumbnails => instagram.thumbnails, :link => ["instagram://location?id=#{instagram.place_id}",
                    "https://itunes.apple.com/us/app/instagram/id389801252"] }
    end

    sub_title = ["There are no drivers available"]
    if !lyft.available_drivers.nil? && lyft.available_drivers > 0
      sub_title = ["#{lyft.available_drivers} drivers availabe - nearest driver is" +
          " #{lyft.closest_driver} away"]
    end
    sub_title.map! { |line| "<p>#{line}</p>" } if format == "html"
    @apps << { :rank => 6, :icon => "lyft.jpg", :title => "Lyft",  :name => "lyft",
        :sub_title => sub_title.join("\n"),
        :link => ["lyft://", "https://itunes.apple.com/us/app/lyft-on-demand-ridesharing/id529379082"] }

    sub_title = ["There are no drivers available"]
    if sidecar.available_drivers > 0
      sub_title = ["#{sidecar.available_drivers} drivers available - " +
                   "nearest driver is #{sidecar.closest_driver} away"]
      unless distance_driving.error
        sub_title << "Fare estimation: #{sidecar.get_fare_calculation(distance_driving.duration,
              distance_driving.miles.to_f, rest_lat, rest_long)}"
      end
    end
    sub_title.map! { |line| "<p>#{line}</p>" } if format == "html"
    @apps << { :rank => 7, :icon => "sidecar.jpg", :title => "SideCar",  :name => "sidecar",
        :sub_title => sub_title.join("\n"),
        :link => ["sidecar://",
                  "https://itunes.apple.com/us/app/sidecar-ride/id524617679"] }

    sub_title = ["ETAs unavailable"]
    sub_title = uber.etas(distance_driving.duration, distance_driving.miles) unless distance_driving.error
    sub_title.map! { |line| "<p>#{line}</p>" } if format == "html"
    @apps << { :rank => 8, :icon => "uber.jpg", :name => "uber", :title => "Uber",
        :sub_title => sub_title.join("\n"),
        :link => ["uber://", "https://itunes.apple.com/us/app/uber/id368677368"] }

    if taximojo
      distance = taximojo.get_distance_to_closest
      sub_title = ["Closest cab is #{distance} away"]
      unless distance_driving.error
        sub_title << ["Fare estimate: $#{taximojo.fare_estimate(distance_driving.miles.to_f,
                      distance_driving.duration)}"]
      end
      sub_title = ["There aren't any available cabs at the moment"] if distance.empty?
    end
    sub_title.map! { |line| "<p>#{line}</p>" } if format == "html"
    @apps << { :rank => 9, :icon => "taximojo.png", :name => "taxiMojo",
        :title => "Use TaxiMojo to get to #{@name}", :sub_title => sub_title.join("\n"),
        :link => ["taximojo://", "https://itunes.apple.com/us/app/taxi-mojo-cab-orders-live/id410129774"] }

    @apps.sort! { |a, b| a[:rank] <=> b[:rank] }
  end

end
