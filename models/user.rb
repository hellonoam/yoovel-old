class User < Sequel::Model
  one_to_one :facebook_token
  one_to_one :google_token
  one_to_one :instagram_token

  def self.update_user_from_google_user_info(user_info, user_id = nil)
    if user_id
      existing_user = User[:id => user_id]
      existing_user.email = user_info["email"]
      return existing_user.save
    end

    existing_user = User[:email => user_info["email"]]
    return User.new(:email => user_info["email"]).save if existing_user.nil?
    existing_user
  end

  def self.update_user_from_facebook_user_info(user_info, user_id = nil)
    if user_id
      existing_user = User[:id => user_id]
      existing_user.facebook_id = user_info["id"]
      return existing_user.save
    end

    existing_user = User[:facebook_id => user_info["id"]]
    return User.new(:facebook_id => user_info["id"]).save if existing_user.nil?
    existing_user
  end
end
