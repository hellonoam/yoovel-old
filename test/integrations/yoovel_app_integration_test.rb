require "faraday"
require "scope"
require "minitest/autorun"
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "db")
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "models", "all")

class YoovelAppIntegrationTest < Scope::TestCase

  # TODO(noam): find out if this is actually doing what I think it is.
  CONNECTED_TO_INTERNET = Faraday.get(URI "http://www.google.com").status == 200 rescue false

  # somewhere in sf
  LAT = 37.774929
  LONG = -122.419415
  LOCATION_DATA = "&lat=#{LAT}&long=#{LONG}"

  context "Yoovel App" do
    setup_once do
      unless CONNECTED_TO_INTERNET
        puts "WARNING: running tests without an internet connection some tests will not run"
      end
      @@conn = Faraday.new(:url => "http://localhost:8080") do |builder|
        builder.request :url_encoded
        builder.adapter :net_http
      end
    end

    context "without login" do
      should "load the index page" do
        last_response = @@conn.get("/")
        assert_equal 200, last_response.status
      end

      should "load location search results" do
        last_response = @@conn.get("/search?q=farina#{LOCATION_DATA}")
        assert_equal 200, last_response.status
        assert_equal nil, last_response.body.index('class="contact"')
        # NOTE(noam): will fail without internet connection
        refute_nil last_response.body.index('class="place"') if CONNECTED_TO_INTERNET
      end

      should "load a place" do
        last_response = @@conn.get("/place?name=Pizzeria%20Delfina&id=44088735f964a52058301fe3" +
            "#{LOCATION_DATA}")
        assert_equal 200, last_response.status
      end
    end

    context "with login" do
      setup_once do
        @@user_id = User.first.id
      end

      should "be logged in" do
        last_response = @@conn.get("/is_logged_in?user_id=#{@@user_id}")
        assert_equal 200, last_response.status
      end

      should "load index page" do
        last_response = @@conn.get("/?user_id=#{@@user_id}")
        assert_equal 200, last_response.status
      end

      should "load search results with people and places" do
        last_response = @@conn.get("/search?q=andrew&user_id=#{@@user_id}#{LOCATION_DATA}")
        assert_equal 200, last_response.status
        # Yes, you need to have at least one contact named andrew for this test to pass!
        refute_nil last_response.body.index('class="place"') if CONNECTED_TO_INTERNET
        refute_nil last_response.body.index('class="contact"') if CONNECTED_TO_INTERNET
      end

      should "load a person" do
        last_response = @@conn.get("http://localhost:8080/person?name=Andrew Meyer" +
            "&google={\"id\":[\"60adb84b088cb579\"]}&facebook={\"id\":\"213732\"}")
        assert_equal 200, last_response.status
      end
    end
  end
end