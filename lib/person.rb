require File.join(File.dirname(File.dirname(__FILE__)), "lib", "envs")

class Person
  attr_reader :first_name, :last_name, :work, :education, :title, :phone_number, :email,
      :sex, :relationship_status, :birthday, :apps

  # TODO: get this somehow from yoovel_app
  INSTAGRAM_AUTH_PATH = "/instagram_login"

  def initialize(person_hash)
    facebook, google = person_hash[:facebook], person_hash[:google]
    twitter, fliptop = person_hash[:twitter], person_hash[:fliptop]
    instagram = person_hash[:instagram]

    @apps = []
    if instagram.authenticated?
      if instagram.thumbnails.empty?
        sub_title = "no grams found"
        sub_title += ", click to open profile" if instagram.username
      else
        sub_title = ""
        [instagram.thumbnails.length, 10].min.times do |i|
          sub_title << "<img src='#{instagram.thumbnails[i]}'>"
        end
      end
      @apps << { :rank => 3, :name => "instagram", :icon => "instagram.png", :title => "Instagram",
            :sub_title => sub_title, :link => "instagram://user?username=#{instagram.username}" }
    else
      @apps << { :rank => 3, :name => "instagram", :icon => "instagram.png", :title => "Instagram",
            :sub_title => "click to authenticate with instagram",
            :link => "https://api.instagram.com/oauth/authorize/?client_id=#{INSTAGRAM_CLIENT_ID}&" +
                "redirect_uri=http://#{APP_URL + INSTAGRAM_AUTH_PATH}&response_type=code" }
    end

    if twitter
      sub_title = twitter.last_tweets.slice(0..1).map { |t| "<p>#{t}</p>" }.join("\n")
      sub_title = "No tweets found :( click to see profile" if sub_title.nil? || sub_title.empty?
      @apps << { :rank => 2, :name => "twitter", :icon => "twitter.png", :title => "Twitter",
            :sub_title => sub_title, :link => "twitter://user?screen_name=#{twitter.username.to_s}" }
    end

    if facebook.id
      sub_title = facebook.statuses_array.slice(0..1).map { |t| "<p>#{t}</p>" }.join("\n")
      sub_title = "No updates here... click to open profile" if sub_title.nil? || sub_title.empty?
      @apps << { :rank => 1, :name => "facebook", :icon => "facebook.png", :title => "Facebook",
            :sub_title => sub_title, :link => "fb://profile/#{facebook.id}" }
    end

    # data that's used to construct the 'title' app
    @first_name, @last_name = facebook.first_name, facebook.last_name
    @first_name ||= google.name if @last_name.nil?
    @email = google.email
    @facebook_profile_pic = facebook.profile_picture
    @phone_number = google.phone_number
    @title = facebook.short_bio

    # NOTE(noam): we're not using this right now, consider removing
    @work = facebook.structured_work
    @education = facebook.structured_education
    @birthday = facebook.birthday_date
    @relationship_status = facebook.relationship_status
    @sex = facebook.sex
    @mutual_friend_count = facebook.mutual_friend_count

    @apps.sort! { |a, b| a[:rank] <=> b[:rank] }
  end

  def description
    @title
  end

  def name
    "#{@first_name} #{@last_name}"
  end

  def profile_pic
    @facebook_profile_pic
  end
end
