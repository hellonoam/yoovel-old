class GoogleToken < Sequel::Model

  one_to_one :user
  # Receives the initial response from Google. This needs to be verified
  # and translates into an actually viable token
  def initialize(google_json_response, code, user_id)
    if !google_json_response || google_json_response["error"]
      puts "somthing went wrong, deal with it! no actually deal with it if it happens"
      return
    end
    args = Hash.new
    args[:access_token] = google_json_response["access_token"]
    # For now is all bearer. But this might change in the future
    args[:token_type] = google_json_response["token_type"]
    args[:expires] = Time.now.to_i + google_json_response["expires_in"]
    args[:id_token] = google_json_response["id_token"]
    args[:refresh_token] = google_json_response["refresh_token"]
    args[:user_id] = user_id
    args[:code] = code
    super(args)
  end

  def expired?
    Time.now.to_i > expires
  end

end
