require "json"
require "rack/test"
require "minitest/autorun"
require File.join(File.expand_path(File.dirname(File.dirname(__FILE__))), "unit_test_helper.rb")
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "lyft_search")
require "scope"
require "rr"

class LyftTest < Scope::TestCase
  include RR::Adapters::TestUnit
  include UnitTestHelper

  # somewhere in sf
  LAT = 37.774929
  LONG = -122.419415

  context "Lyft" do
    should "return nearest cab in miles" do
      stub_request(lyft_response)
      lyft = LyftSearch.new(LAT.to_s, LONG.to_s)
      assert_equal 2, lyft.available_drivers
      # TODO(noam): maybe check also the closest_driver, would need to stub google dist
    end
  end

  def lyft_response
    { :drivers => [ { :lat => LAT, :lng => LONG }, { :lat => LAT, :lng => LONG + 1 } ] }.to_json
  end
end