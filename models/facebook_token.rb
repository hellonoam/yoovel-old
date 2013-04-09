class FacebookToken < Sequel::Model
  one_to_one :user

  def initialize(params, user_id = nil)
    # This is not really needed but just to make sure user defined params don't end up here.
    args = Hash.new
    args[:expires] = params["expires"].to_i + Time.now.to_i
    args[:code] = params[:code]
    args[:access_token] = params["access_token"]
    args[:user_id] = user_id
    super(args)
  end
end