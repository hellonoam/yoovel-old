require "faraday"
require "json"
require "lrucache"

class FacebookSearch
  attr_reader :id, :first_name, :last_name, :email, :profile_picture, :username, :birthday_date,
              :education, :work, :statuses, :about, :relationship_status, :sex, :mutual_friend_count

  USE_CACHE = true

  @@contacts_cache = LRUCache.new(:ttl => 1.hour, :max_size => 1000)

  def initialize(user, query = nil)
    return if user.nil? || user.facebook_token.nil?
    @query = query
    @token = user.facebook_token
    @user_id = user.id
    perform unless @query.nil?
  end

  def search_cache(query)
    contacts = get_all_contacts
    return {} if contacts.nil?
    contacts.select { |k,v| k.downcase.index(query.downcase) }
  end

  def get_all_contacts
    return {} if @token.nil? || @token.access_token.nil?
    if USE_CACHE
      cached_result = @@contacts_cache.fetch(@user_id)
      return cached_result unless cached_result.nil?
    end
    result_set = {}
    response = FaradayConnections.make_request_through_cache(URI "https://graph.facebook.com" +
        "/me/friends?access_token=#{@token.access_token}")
    begin
      JSON.parse(response.body)["data"].each do |contact_entry|
        result_set[contact_entry["name"]] = contact_entry["id"]
      end
    rescue Exception => e
      puts "DEBUG: body: #{response.body} \n #{e} #{e.backtrace.join("\n")}"
    end
    result_set = Hash[result_set.sort]
    @@contacts_cache.store(@user_id, result_set) if USE_CACHE
    result_set
  end

  def is_number?(query)
    query.to_i.to_s == query
  end

  def perform
    return "" if @token.nil? || @query.empty?
    @access_token_param = "access_token=#{@token.access_token}" unless @token.access_token.nil?
    # see again if we can do this with fql
    if !is_number?(@query)
      res = FaradayConnections.make_request_through_cache(URI "https://graph.facebook.com" +
          "/search?q=#{URI.encode @query}&type=user&#{@access_token_param}")
      run_query_for_facebook_id(res.body, false)
   else
      # Its a facebook_id from the object hash
      run_query_for_facebook_id({ "id" => @query }, true)
    end
  end

  def run_query_for_facebook_id(person, have_id)
    begin
      person = JSON.parse(person)["data"][0] unless have_id
      return "" if person.nil?
      @id = person["id"]
      fql_select = "SELECT first_name,last_name,email,username,pic_square,pic_big,pic_small"
      # Permissions granted on a friend basis, which we have enabled if we have an id (since it results from
      # a friends search
      fql_select += ",education,work,birthday_date,sex,relationship_status,mutual_friend_count" if have_id
      fql_from = " FROM user WHERE uid=#{person["id"]}"
      fql_friend = (fql_select + fql_from).gsub(" ", "+")
      fql_status = "SELECT status_id,message FROM status WHERE uid=#{person["id"]}".gsub(" ", "+")
      fql = {
        "query1" => fql_friend,
        "query2" => fql_status
      }
      response = FaradayConnections.make_request_through_cache(URI "https://graph.facebook.com" +
          "/fql?q=#{URI.encode fql.to_json}&#{@access_token_param}")

      json_response = JSON.parse(response.body)
      person = json_response["data"][0]["fql_result_set"][0]

      @first_name, @last_name, @email = person["first_name"], person["last_name"], person["email"]
      @work, @education, @about = person["work"], person["education"], person["about"]
      @sex, @relationship_status = person["sex"], person["relationship_status"]
      @profile_picture, @username = person["pic_big"], person["username"]
      @mutual_friend_count, @birthday_date = person["mutual_friend_count"], person["birthday_date"]

      @statuses = safe_traverse(["data", 1, "fql_result_set"], [json_response], nil, false)

      ""
    rescue Exception => e
      puts "ERROR (facebook search) - last_response: #{response}. #{e} #{e.backtrace.join("\n")}"
    end
  end

  def statuses_array
    statuses = []
    return statuses if @statuses.nil?
    @statuses.each_with_index do |status, index|
      statuses << status["message"] if index < 5
    end
    return statuses
  end

  def short_bio
    employer_name = safe_traverse(["employer", "name"], @work)
    employer_location = safe_traverse(["location", "name"], @work)
    school_name = safe_traverse(["school", "name"], @education)
    graduation_year = safe_traverse(["year", "name"], @education)

    info = []
    info << @about unless @about.to_s.empty?
    info << "worked at #{employer_name}" unless employer_name.empty?
    info << employer_location unless employer_location.empty?
    info << "#{school_name} #{graduation_year}" unless school_name.empty?

    info.join(", ")
  end

  def structured_work
    employers = []
    return employers if @work.nil?
    @work.length.times do |i|
      employer_name = safe_traverse(["employer", "name"], @work, i)
      employer_location = safe_traverse(["location", "name"], @work, i)
      employers << { :name => employer_name, :location => employer_location }
    end
    employers
  end

  def structured_education
    educations = []
    return educations if @education.nil?
    @education.length.times do |i|
      school_name = safe_traverse(["school", "name"], @education, i)
      graduation_year = safe_traverse(["year", "name"], @education, i)
      degree = safe_traverse(["degree", "name"], @education, i)
      type = safe_traverse(["type", "name"], @education, i)
      concentration = safe_traverse(["concentration", "name"], @education, i)
      educations << { :name => school_name, :year => graduation_year, :type => type, :degree => degree,
                      :concentration => concentration }
    end
    educations
  end

  def safe_traverse(entries, data, position = nil, first = true)
    return "" if data.nil?
    value = position.nil? ? data.last : data[position]
    entries.each do |entry|
      value = value.first if value.is_a?(Array) && first
      value = (value && !value.empty?) ? value[entry] : ""
    end
    value.nil? ? "" : value
  end

end
