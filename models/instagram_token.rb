require "uri"

class InstagramToken < Sequel::Model

  one_to_one :user

  INSTAGRAM_EXPIRY_TEST_URL = "https://api.instagram.com/v1/users/self"

  def initialize(instagram_json_response, code, user_id)
    if !instagram_json_response || instagram_json_response["error"]
      puts "somthing went wrong, deal with it! no actually deal with it if it happens"
      return
    end
    args = Hash.new
    args[:access_token] = instagram_json_response["access_token"]
    args[:user_id] = user_id
    args[:code] = code
    super(args)
  end

end
