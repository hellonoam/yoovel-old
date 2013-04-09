require "faraday"
require "scope"
require "cgi"
require "minitest/autorun"
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "db")
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "faraday_connections")
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "opentable_search")
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "models", "all")

class OpentableAvailabilityIntegration < Scope::TestCase

  # somewhere in sf
  LAT = 37.774929
  LONG = -122.419415

  context "Test Opentable Reservation Availability" do
    setup_once do
      # Limon on Valencia
      @restaurant_id = 47881
      @future_date = CGI::escape("2013-04-01T11:00:00")
      @future_time = CGI::escape("0001-01-01T15:00:00")
    end

    context "Limon in the future" do
      # This is extremely hacky and will only work as long as we're far from April 2013
      should "show available tables" do
        ot_search = OpentableSearch.new(@restaurant_id, 2, @future_date, @future_time)
        assert(ot_search.is_restaurant_available?, "Table is unavailable despite. Check logs and potentially"+
                    "fix OT APIs")
      end

    end

  end
end
