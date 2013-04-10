require "sinatra/base"
require "sinatra/synchrony"
require 'sinatra/redis'
require "resque"
require "set"
require File.join(Dir.pwd, "lib", "db")
require File.join(Dir.pwd, "models", "all")
require File.join(Dir.pwd, "lib", "google", "all")
require File.join(Dir.pwd, "lib", "instagram", "all")
require File.join(Dir.pwd, "lib", "facebook", "all")
require File.join(Dir.pwd, "lib", "fliptop_search")
require File.join(Dir.pwd, "lib", "opentable_search")
require File.join(Dir.pwd, "lib", "twitter_search")
require File.join(Dir.pwd, "lib", "foursquare_search")
require File.join(Dir.pwd, "lib", "taximojo_search")
require File.join(Dir.pwd, "lib", "lyft_search")
require File.join(Dir.pwd, "lib", "instantcab_search")
require File.join(Dir.pwd, "lib", "sf_eater")
require File.join(Dir.pwd, "lib", "founders_choice")
require File.join(Dir.pwd, "lib", "uber_search")
require File.join(Dir.pwd, "lib", "sidecar_search")
require File.join(Dir.pwd, "lib", "yelp_search")
require File.join(Dir.pwd, "lib", "whitelist")
require File.join(Dir.pwd, "lib", "envs")
require File.join(Dir.pwd, "lib", "person")
require File.join(Dir.pwd, "lib", "place")
require File.join(Dir.pwd, "lib", "song")
require File.join(Dir.pwd, "lib", "faraday_connections")
require File.join(Dir.pwd, "lib", "host_changer")
require File.join(Dir.pwd, "redis", "venue_jobs")
require "em-synchrony/fiber_iterator"
require "coffee-script"
require "sass"
require "json"

class YoovelApp < Sinatra::Base
  register Sinatra::Synchrony

  set :public_folder, "public"
  enable :sessions
  enable :logging
  set :threaded, true

  BETA_COOKIE_NAME = "youvebeencorraled"

  AUTH_PATHS = ["search", "", "place", "person", "is_logged_in"].join("|")

  GOOGLE_AUTH_PATH = "/google_login"
  FACEBOOK_AUTH_PATH = "/facebook_login"
  INSTAGRAM_AUTH_PATH = "/instagram_login"

  SF_EATER = "Trendy Eats by SF Eater"
  FOUNDERS_CHOICE = "Corral Picks"

  configure do
    # TODO: maybe move this to a redis init since it's in the rakefile as well.
    uri = URI.parse(REDIS_URL)
    Resque.redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
    use Rack::CommonLogger
    use Rack::Deflater
    # don't use host changer for now.
    # use HostChanger
  end

  configure :development, :test do
    STDERR.sync
    STDOUT.sync

    require "sinatra/reloader"
    register Sinatra::Reloader
    also_reload "*/*.rb"
    also_reload "*/*/*.rb"
  end

  before "*" do
    return unless dev?
    user = User[:id => session[:user_id]]
    debug_puts "user_id=#{session[:user_id]} " +
               "facebook exists? #{!user.nil? && !user.facebook_token.nil?} " +
               "google exists? #{!user.nil? && !user.google_token.nil?}"
    if user.nil?
      user = User[:id => params[:user_id]]
      session[:user_id] = user.id unless user.nil?
    end
  end

  before /\A\/(#{AUTH_PATHS})\z/ do
    @user = User[:id => session[:user_id]]
    if @user.nil? || @user.google_token.nil? || @user.facebook_token.nil?
      # Removed the redirect to login since we can do search without the user being logged in. Just doesn't
      # have contacts results.
    end
  end

  # Compile coffeescript files that are in the views folder
  get "/js/*.coffee" do |filename|
    public_filename = "#{settings.public_folder}/js/#{filename}.js"
    return send_file(public_filename) if !dev? && File.exists?(public_filename)

    compiled = coffee "/js/#{filename}".to_sym
    File.open(public_filename, "w") { |f| f.write(compiled) } unless dev?

    content_type "text/javascript", :charset => "utf-8"
    compiled
  end

  # Compile scss files that are in the views folder
  get "/css/*.scss" do |filename|
    public_filename = "#{settings.public_folder}/css/#{filename}.css"
    return send_file(public_filename) if !dev? && File.exists?(public_filename)

    compiled = scss "/css/#{filename}".to_sym, :style => :expanded
    File.open(public_filename, "w") { |f| f.write(compiled) } unless dev?

    content_type "text/css", :charset => "utf-8"
    compiled
  end

  get "/is_logged_in" do
    halt 400 if @user.nil?
  end

  get "/login" do
    @user = User[:id => session[:user_id]]
    redirect to("/") if @user && @user.facebook_token && @user.google_token
    render_with_layout(:login)
  end

  get "/logout" do
    "<!DOCTYPE html>" +
    "<script src='http://ajax.googleapis.com/ajax/libs/jquery/1.8.2/jquery.min.js'></script>" +
    "<script>$.post('/logout', function() { window.location = '/' })</script>"
  end

  post "/logout" do
    session[:user_id] = nil
    redirect to("/login")
  end

  get "/secret_link" do
    redirect to("/")
  end

  get "/" do
    contacts = {}
    classes = [FacebookSearch, GoogleSearch]
    EM::Synchrony::FiberIterator.new(classes, classes.length).each do |klass|
      klass.new(@user).get_all_contacts
    end
    render_with_layout(:search, {}, [], ["search_result.scss"])
  end

  get "/discovery_keywords" do
    [SF_EATER, FOUNDERS_CHOICE, "Brunch", "Lunch", "Dinner", "Italian", "Thai", "Peruvian", "Mexican",
    "Burger", "Steakhouse", "Chinese", "Indian", "Greek", "Sushi", "French", "Cajun", "Pizza"].to_json
  end

  get "/search" do
    format = params[:format]
    query = params[:q].to_s
    lat = params[:lat]
    long = params[:long]

    google_results = GoogleSearch.new(@user).search_cache(query)
    facebook_results = FacebookSearch.new(@user).search_cache(query)

    # this is actually only used for mixpanel in the template.
    discovery_results = true
    if query == SF_EATER
      places_results = SFEater.new(lat, long).recommendations
    elsif query == FOUNDERS_CHOICE
      places_results = FoundersChoice.new(lat, long).recommendations
    elsif Whitelist::in_discovery_whitelist(query)
      places_results = YelpSearch.new(query, lat, long, 20, false).search_results
    else
      discovery_results = false
      places_results = FoursquareSearch.new(query, lat, long, false).search_result
    end

    if places_results
      places_results.each do |name, all_venues_with_name|
        all_venues_with_name.each do |venue_hash|
          if venue_hash["location"] && venue_hash["location"]["coordinate"]
            rest_lat = venue_hash["location"]["coordinate"]["latitude"]
            rest_long = venue_hash["location"]["coordinate"]["longitude"]
          end
          rest_lat ||= lat
          rest_long ||= long
          query_link = "name=#{CGI::escape name}&" +
                       "foursquare_id=#{CGI::escape venue_hash["foursquare_id"].to_s}&" +
                       "yelp_id=#{CGI::escape venue_hash["yelp_id"].to_s}&" +
                       "rest_lat=#{rest_lat}&rest_long=#{rest_long}"
          venue_hash.merge!({ "details_query_string" => query_link, "rank" => corral_score(venue_hash) })
        end
      end
    end
    return places_results.to_json if format == "json"
    people_results = merge_facebook_google_contacts(facebook_results, google_results)
    erb :search_results, :locals => { :people_results => people_results,
                                      :places_results => places_results, :lat => lat, :long => long,
                                      :discovery_mode => discovery_results, :query => query }
  end

  get "/song" do
    render_with_layout(:generic_search_result, { :item => Song.new({}) }, [], ["search_result.scss"])
  end

  get "/transport" do
    halt 400, "invalid value for param origin" if params[:origin].to_s.index(",").nil?
    lat, long = params[:origin].split(",").map { |loc| loc.to_f.round(4) }
    dest_exists = params[:destination]
    dest_lat, dest_long = params[:destination].split(",").map { |loc| loc.to_f.round(4) } if dest_exists

    searches = {
                 # :lyft    => [LyftSearch, lat, long],
                 :instantcab => [InstantcabSearch, lat, long],
                 :uber       => [UberSearch, lat, long]
               }

    # searches that require a destination.
    if dest_exists
      searches.merge!({
        :sidecar          => [SidecarSearch, lat, long, dest_lat, dest_long],
        :public_transport => [GoogleDirections, [dest_lat, dest_long], [lat, long]],
        :distance_driving => [GoogleDistance, [dest_lat, dest_long], [lat, long], "driving"],
        :distance_walking => [GoogleDistance, [dest_lat, dest_long], [lat, long], "walking"],
        :distance_cycling => [GoogleDistance, [dest_lat, dest_long], [lat, long], "bicycling"]
      })
    end

    search_results = {}
    EM::Synchrony::FiberIterator.new(searches, searches.length).each do |name, klass_and_args|
      klass, *args = klass_and_args
      search_results[name] = klass.new *args
    end

    if dest_exists && !search_results[:distance_driving].error
      search_results[:uber].add_prices_to_types(search_results[:distance_driving].duration,
          search_results[:distance_driving].miles)
      search_results[:sidecar].get_fare_calculation(search_results[:distance_driving].duration,
          search_results[:distance_driving].miles, dest_lat, dest_long)
    end

    search_results.reject! { |_,v| v.error }

    return search_results.map { |_, v| v.public_model }.to_json if params[:format] == "json"
  end

  get "/maps/api/directions/json" do
    return File.read(File.join File.dirname(__FILE__), "google_directions_dummy_data")
  end

  get "/place" do
    format = params[:format]
    foursquare_id = URI::decode params[:foursquare_id].to_s
    yelp_id = URI::decode params[:yelp_id].to_s
    name = URI.decode params[:name]
    party_size = params[:party]
    discovery_mode = params[:discovery] && params[:discovery] == "true"
    lat = params[:lat].to_f.round(4)
    long = params[:long].to_f.round(4)
    rest_lat = params[:rest_lat]
    rest_long = params[:rest_long]

    fs_search = (foursquare_id && foursquare_id != "") ?
        # I'm not sure why we have lat/long here and not rest_lat/rest_long
        FoursquareSearch.new(foursquare_id, lat, long) :
        FoursquareSearch.new(name, rest_lat, rest_long, false, true)

    valid_yelp_id = yelp_id && yelp_id != ""
    yelp_query = valid_yelp_id ? yelp_id : name
    search_results = {}
    search_results[:foursquare] = fs_search
    searches = { :opentable        => [OpentableSearch, fs_search.opentable_id, party_size],
                 :taximojo         => [TaximojoSearch, lat, long],
                 :google_places    => [GooglePlaces, name, rest_lat, rest_long],
                 :yelp             => [YelpSearch, yelp_query, rest_lat, rest_long, 1, valid_yelp_id],
                 :lyft             => [LyftSearch, lat, long],
                 :sidecar          => [SidecarSearch, lat, long, rest_lat, rest_long],
                 :uber             => [UberSearch, lat, long],
                 :public_transport => [GoogleDirections, fs_search.full_address, [lat, long]],
                 :distance_driving => [GoogleDistance, fs_search.full_address, [lat, long], "driving"],
                 :distance_walking => [GoogleDistance, fs_search.full_address, [lat, long], "walking"],
                 :distance_cycling => [GoogleDistance, fs_search.full_address, [lat, long], "bicycling"],
                 :instagram        => [InstagramVenueSearch, fs_search.id]
               }

    EM::Synchrony::FiberIterator.new(searches, searches.length).each do |name, klass_and_args|
      klass, *args = klass_and_args
      search_results[name] = klass.new *args
    end
    search_results[:rest_location] = [rest_lat, rest_long]

    foursquare, yelp =search_results[:foursquare], search_results[:yelp]
    venue = Venue[:yelp_id => yelp.id] || Venue[:foursquare_id => foursquare.id] || Venue.new()
    # TODO: if we want to optimize we can do this only if anything has changed.
    venue.update(:name => name, :yelp_id => yelp.id, :foursquare_id => foursquare.id,
        :foursquare_rating => foursquare.rating, :yelp_rating => yelp.rating,
        :address => foursquare.display_address, :lat => rest_lat, :long => rest_long)

    place = Place.new(search_results, format || "html")
    return place.to_json if format == "json"
    render_with_layout(:places_search_result, { :place => place }, [], ["search_result.scss"])
  end

  get "/person" do
    query = URI::decode params[:name]
    person_hash = {}

    person_hash[:query] = query

    # Google is unable to global search, so dont bother searching if we dont have an id
    google_query = JSON.parse(URI::decode params[:google])["id"] rescue nil
    facebook_query = JSON.parse(URI::decode params[:facebook])["id"] || query rescue query

    search_results = {}
    searches = { :facebook  => [FacebookSearch, @user, facebook_query],
                 :google    => [GoogleSearch, @user, google_query],
                 :instagram => [InstagramSearch, @user, query] }
    EM::Synchrony::FiberIterator.new(searches, searches.length).each do |name, klass_and_args|
      klass, *args = klass_and_args
      search_results[name] = klass.new *args
    end

    # Maybe use facebook for email, but right doens't work search_results[:facebook].email
    @email = search_results[:google].email

    search_results[:fliptop] = FliptopSearch.new(@email) if @email && !@email.empty?
    @twitter_account_id = search_results[:fliptop].twitter_username if search_results[:fliptop]

    search_results[:twitter] = @twitter_account_id ? TwitterSearch.new(@twitter_account_id) : nil

    render_with_layout(:people_search_result, { :person => Person.new(search_results)  }, [],
        ["search_result.scss"])
  end

  get INSTAGRAM_AUTH_PATH do
    instagram_auth = InstagramAuth.new(params[:code], INSTAGRAM_AUTH_PATH, request.query_string)
    instagram_token = InstagramToken.new(instagram_auth.instagram_auth_response, params[:code],
        session[:user_id])
    # We'll only be in this callback if a) no token existed or b) the token expired. Eithe way we need to save
    instagram_token.save
    # TODO(noam): There's a bug here, it doesn't save all query strings from where you clicked the link.
    redirect to "/"
  end

  get GOOGLE_AUTH_PATH do
    google_auth = GoogleAuth.new(params[:code], GOOGLE_AUTH_PATH)
    google_token = GoogleToken.new(google_auth.google_oauth_response, params[:code], session[:user_id])
    user_info = google_auth.get_user_info()
    user = User.update_user_from_google_user_info(user_info, session[:user_id])
    session[:user_id] = user.id
    if user.google_token.nil?
      google_token.user_id = user.id
      google_token.save
    elsif user.google_token.expired?
      GoogleAuth.refresh_token(user)
    end
    redirect to("/")
  end

  get FACEBOOK_AUTH_PATH do
    facebook_auth = FacebookAuth.new(params[:code], params[:error], FACEBOOK_AUTH_PATH)
    new_fb_user = FacebookToken.new(facebook_auth.facebook_oauth_response, session[:user_id])
    user_info = facebook_auth.get_user_info
    user = User.update_user_from_facebook_user_info(user_info, session[:user_id])
    session[:user_id] = user.id
    if user.facebook_token.nil?
      new_fb_user.user_id = user.id
      new_fb_user.save
    end
    redirect to("/")
  end

  def merge_facebook_google_contacts(facebook_hash, google_hash)
    merged_hash = {}
    google_hash.each do |name, id|
      next if is_number?(name)
      name = captalize_person_name(name)
      merged_hash[name] = {}
      facebook_id = facebook_hash[name]
      merged_hash[name]["facebook"] = { "id" => facebook_id } if facebook_id
      merged_hash[name]["google"] = { "id" => id }
    end
    facebook_hash.each do |name, id|
      next if is_number?(name)
      name = captalize_person_name(name)
      next if merged_hash.include?(name)
      merged_hash[name] = {}
      merged_hash[name]["facebook"] = { "id" => id }
    end
    Hash[merged_hash.sort]
  end

  private

  def corral_score(venue_hash)
    fs = venue_hash["foursquare_rating"].to_f
    yelp = venue_hash["yelp_rating"].to_f
    return yelp if fs == 0
    (yelp * 2 + fs/2) / 3
  end

  def captalize_person_name(name)
    name = name.split(" ").map do |n|
      n = n.capitalize
      n = n.split("-").map(&:capitalize).join("-")
    end.join(" ")
  end

  def dev?
    ENV["RACK_ENV"] == "development" || ENV["RACK_ENV"] == "test"
  end

  def is_number?(query)
    query.to_i.to_s == query
  end

  def debug_puts(s)
    puts "DEBUG: #{Time.now} - #{s}" if dev?
  end

  # Renders the template with the base template which requires the template's coffee and scss file.
  # Will add script tags on the template for the additional_js and pass the locals to the template.
  def render_with_layout(template, locals = {}, additional_js = [], additional_css = [])
    script_tags = ""
    css_tags = ""
    additional_js.each { |fileName| script_tags << "<script src='/js/#{fileName}'></script>" }
    additional_css.each do |fileName|
      css_tags << "<link rel='stylesheet' type='text/css' href='/css/#{fileName}'/>"
    end
    erb :base, :locals => locals.merge({ :template => template, :user => @user,
                                         :script_tags => script_tags, :css_tags => css_tags })
  end

  helpers do
    def basic_info(person)
      info = []
       info << "Birthday: #{person.birthday}" if person.birthday
       info << person.sex if person.sex
       info << "#{person.mutual_friend_count} mutual friends" if person.mutual_friend_count
       info << person.relationship_status if person.relationship_status
       info << "couldn't find anything, sorry" if info.empty?
       info.join(", ")
    end
  end

end

