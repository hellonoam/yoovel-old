require "faraday"
require "scope"
require "minitest/autorun"
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "lyft_search")

class LyftIntegrationTest < Scope::TestCase

  # somewhere in sf
  LAT = 37.774929
  LONG = -122.419415

  context "Lyft" do
    should "get a valid response for drivers" do
      lyft = LyftSearch.new(LAT, LONG)
      assert lyft.available_drivers >= 0
      if lyft.available_drivers > 0
        puts "LYFT: drivers found"
        assert lyft.closest_driver.is_a?(String)
      else
        puts "LYFT: no drivers found"
        assert_equal nil, lyft.closest_driver
      end
    end
  end

end