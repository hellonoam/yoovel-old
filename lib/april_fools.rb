require File.join(File.dirname(File.dirname(__FILE__)), "lib", "transport_app_integration")

class AprilFools < TransportAppIntegration

  attr_reader :error

  def initialize
    @error = false
    @rank = 0
    @name = "Corral Special"
    @app_icon_name = "yelp.jpg"
    @links = ["http://www.getcorral.com/aprilfools"]
    @description = "1 private jet close by click to hail it"
    @price = "free"
  end
end
