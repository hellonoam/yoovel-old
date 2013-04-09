require "oauth"
require "lrucache"

class YelpSearch

  attr_reader :id, :url, :rating, :rating_photo, :photo, :review, :phone_number, :closed, :search_results

  CONSUMER_KEY = "PfWAkCM2CGpBzPZaiLnUww"
  CONSUMER_SECRET = "krACYq1zA7RuSdScTaHRxTOjEMo"
  TOKEN = "MYC8jS2U5YmTB9kYyF62Te-obQVlaXHy"
  TOKEN_SECRET = "c4tzBr_8ReLeL_gNWYehq-OaYxM"

  OAuthConfig = {
    :consumer_key     => CONSUMER_KEY,
    :consumer_secret  => CONSUMER_SECRET,
    :access_token     => TOKEN,
    :access_token_secret => TOKEN_SECRET
  }

  DEFAULT_TTL = 6.hours

  @@venue_cache = LRUCache.new(:ttl => DEFAULT_TTL, :max_size => 1000)

  @@consumer = OAuth::Consumer.new(CONSUMER_KEY, CONSUMER_SECRET, { :site => "http://api.yelp.com" })
  @@access_token = OAuth::AccessToken.new(@@consumer, TOKEN, TOKEN_SECRET)
  # TODO(noam): Consider using this for em oauth
  # @@conn = EventMachine::HttpRequest.new("http://api.yelp.com")
  # @@conn.use EventMachine::Middleware::OAuth, OAuthConfig

  @search_results = {}

  def initialize(query, lat, long, result_size, query_is_id, display_full_result=true)
    @query, @lat, @long = query, lat, long
    begin
      query_yelp(query, query_is_id, result_size)
      if result_size == 1 && display_full_result == true
        @result = @search_results.values.first.first
        @url, @rating, @rating_photo = @result["mobile_url"], @result["rating"], @result["rating_img_url"]
        @photo, @review, @id = @result["image_url"], @result["snippet_text"], @result["id"]
        @phone_number, @closed = @result["phone"], @result["is_closed"]
      else
        smaller_search_results = {}
        @search_results.each do |k, multiple_values|
          smaller_search_results[k] = multiple_values.map do |v|
            address = [v["location"]["address"][0], v["location"]["city"]].reject(&:nil?).join(" ")

            # if venue isn't in the db add it!
            venue = Venue[:yelp_id => v["id"]] ||
                    Venue.new(:yelp_id => v["id"], :yelp_rating => v["rating"], :address => address,
                        :name => k, :lat => v["location"]["coordinate"]["latitude"],
                        :long => v["location"]["coordinate"]["longitude"]).save
            venue.public_model(lat, long)
          end
        end
        @search_results = smaller_search_results
      end
    rescue Exception => e
      puts "ERROR (yelp search): couldn't parse json response #{e.message}"
    end
  end

  def query_yelp(query, query_is_id, result_size)
    path = "/v2/search?term=#{URI.encode query}&ll=#{@lat},#{@long}&limit=#{result_size}"
    if query_is_id == true
      path = "/v2/business/#{URI.encode query}"
    end

    cache_key = query_is_id ? query : key_with_loc(query)
    @search_results = @@venue_cache.fetch(cache_key)
    if @search_results.nil?
      debug_puts "yelp - did not find results in cache for key #{cache_key}"
      @search_results = {}
      response = JSON.parse(@@access_token.get(path).body)
      # Conform the two result sets
      if query_is_id
        response = { "businesses" => [response] }
      end
      result_size = [result_size, response["businesses"].length].min
      result_size.times do |i|
        venue_name = response["businesses"][i]["name"]
        venue = response["businesses"][i]
        if @search_results[venue_name].nil?
          @search_results[venue_name] = [venue]
        else
          @search_results[venue_name].push(venue)
        end
        # Store the actual restaurant in the cache as well in addition to the search
        # Using a weird datastructure for storage to keep processing the same across
        # Yelp and Foursquare, and within Yelp between cached and uncached
        @@venue_cache.store(venue["id"], { venue["id"] => [venue] })
      end
      @@venue_cache.store(cache_key, @search_results)
    else
      debug_puts "yelp - got search_results from cache for key #{cache_key}"
    end
  end

  def key_with_loc(query)
    "#{query},#{@lat},#{@long}"
  end

  def debug_puts(s)
    puts "DEBUG: #{Time.now} - #{s}"
  end


end
