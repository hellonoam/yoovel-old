require "json"
require "rack/test"
require "minitest/autorun"
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "taximojo_search")
require File.join(File.expand_path(File.dirname(File.dirname(__FILE__))), "unit_test_helper.rb")
require "scope"
require "rr"

class TaximojoTest < Scope::TestCase
  include RR::Adapters::TestUnit
  include UnitTestHelper

  # somewhere in sf
  LAT = 37.774929
  LONG = -122.419415

  context "Taximojo" do
    should "return nearest cab in miles" do
      stub_request(taximojo_response(LAT + 1, LONG))
      distance = { :metric => "miles", :amount => 69.05 }
      assert_equal distance, TaximojoSearch.new(LAT.to_s, LONG.to_s).get_distance_to_closest
    end

    should "return nearest cab in feet" do
      stub_request(taximojo_response(LAT, LONG))
      distance = { :metric => "feet", :amount => 0 }
      assert_equal distance, TaximojoSearch.new(LAT.to_s, LONG.to_s).get_distance_to_closest
    end
  end

  def taximojo_response(lat, long)
    { :drivers => [ :coordinates => { :latitude => lat, :longitude => long } ] }.to_json
  end
end