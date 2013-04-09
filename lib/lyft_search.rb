require "lrucache"
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "transport_app_integration")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "faraday_connections")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "dist_calc")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "google", "google_distance")

class LyftSearch < TransportAppIntegration

  attr_reader :available_drivers, :closest_driver, :error

  # ahhhh oohhhh hhhhhmmmmmm aaaaaa this shouldn't be here probably unless you want the company credit card to
  # be used for free rides
  LYFT_AUTH = "fbAccessToken " +
"BAAD6nt9dOocBAIFzf88Wg97hNI9hzaM3Dk11yUHX2DlhspjQAuXqZCozZCjHBLVd4kwDHCIi78mFOmOTe9QAx8yfOpY1KkeLeCReVXJiicDEtrS01A246aD7Q8bNConBMWGmi579MdXKsN1ulOE6BVuLxudO4RFhdOmSoHzsw70y1KeZCR0vZARy8TInGyX9ekYQeqbkuw16AhkAVdKUPNlZB1M2217oZD"

# Noam's lyft token fbAccessToken BAAD6nt9dOocBAM9gnR1vKZBIDxNw8VI97VN6vURcoF2IdWFCfGwu4IacldV6rPzVsVG958mfHFveetTvMQQO4F8cDjDX9Tl09LzDQqnnslH6wgGR1qx1rEFGxkZApngZCLgqr10wwZDZD

  LYFT_QUERY_URL = "https://lyft.zimride.com/users/me/location"

  def initialize(lat, long)
    @rank = 1
    @name = "Lyft"
    @app_icon_name = "lyft.jpg"
    @links = ["fb275560259205767lyft://",
        "https://itunes.apple.com/us/app/lyft-on-demand-ridesharing/id529379082"]
    response = FaradayConnections.make_request(
        URI(LYFT_QUERY_URL), true, { :lat => @lat, :lng => @long,
        :markerLng => long, :markerLat => lat }.to_json, "Lyft:android:4.0.4:1.1.9", LYFT_AUTH)
    begin
      drivers = JSON.parse(response.body)["drivers"]
      drivers = [] if drivers.nil?
      @available_drivers = drivers.length
      @closest_driver = calculate_closest_driver(drivers, lat, long)
      @description = "#{@available_drivers} drivers available, nearest #{@closest_driver} away"
      @description = "No drivers available" if @available_drivers == 0
    rescue
      @error = true
      puts "ERROR (lyft): couldn't get drivers from response"
    end
  end

  def calculate_closest_driver(drivers, lat, long)
    return nil if drivers.empty?
    drivers.map! do |d|
      d[:dist] = DistCalc::distance_between_points(lat, long, d["lat"], d["lng"])
      d
    end
    closest = drivers.min_by { |d| d[:dist][:miles] }
    # Maybe use this in the future with miles * 5 mins as an estimate
    # DistCalc::format_distance(@drivers.first[:dist])
    GoogleDistance.new([closest["lat"], closest["lng"]], [lat, long]).duration_text
  end

end
