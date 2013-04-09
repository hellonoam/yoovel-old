require "faraday"
require "scope"
require "minitest/autorun"
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "sidecar_search")

class SidecarIntegrationTest < Scope::TestCase

  # somewhere in sf
  LAT = 37.774929
  LONG = -122.419415

  context "Sidecar" do
    setup_once do
      @@sidecar = SidecarSearch.new(LAT, LONG)
    end

    should "get a valid response for drivers" do
      assert @@sidecar.available_drivers >= 0
      if @@sidecar.available_drivers > 0
        puts "SIDECAR: drivers found"
        assert @@sidecar.closest_driver.is_a?(String) && !@@sidecar.closest_driver.empty?
      else
        puts "SIDECAR: no drivers found"
        assert_equal nil, @@sidecar.closest_driver
      end
    end

    should "get fare estimate" do
      assert_equal 9, @@sidecar.get_fare_calculation(5, 5)
    end
  end

end