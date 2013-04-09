require "json"
require "uri"
require "faraday"
require "rexml/document"
require File.join(File.dirname(File.dirname(File.dirname(__FILE__))), "lib", "envs")
require "active_support/core_ext"
require "lrucache"

class GoogleSearch

  attr_accessor :result

  USE_CACHE = true

  @@contacts_cache = LRUCache.new(:ttl => 1.hour, :max_size => 100)

  GOOGLE_OAUTH_PATHS = {
    "USER_INFO" => "https://www.googleapis.com/oauth2/v1/userinfo?",
    "GMAIL_ATOM" => "https://mail.google.com/mail/feed/atom",
    "ALL_CONTACTS" => "https://www.google.com/m8/feeds/contacts/default/full"
  }

  def initialize(user, query = nil)
    return if user.nil? || user.google_token.nil?
    GoogleAuth.refresh_token(user) if user.google_token.expired?
    @query = query
    @user_id = user.id
    @token = user.google_token
    perform unless @query.nil?
  end

  def search_cache(query)
    contacts = get_all_contacts
    return {} if contacts.nil?
    contacts.select { |k,v| k.downcase.index(query.downcase) }
  end

  def name
    name = traverse_result(["entry", "title"])
  end

  def email
    email = traverse_result(["entry", "email"])
    email = [email] unless email.is_a? Array
    email.map { |e| traverse_result(["address"], e) }
  end

  def phone_number
    number = traverse_result(["entry", "phoneNumber"])
    # TODO(noam): grab the other numbers as well
    number = number[0] if number.is_a? Array
    number
  end

  def traverse_result(entries, result = @result)
    value = result
    entries.each { |entry| value = value[entry] if value }
    value
  end

  def perform
    return "" if @token.nil? || @query.nil?
    result_set = []
    EM::Synchrony::FiberIterator.new(@query, @query.length).each do |one_query|
      result_set << get_contacts(one_query)
    end
    @result = flatten_json_result(result_set).values.first
  end

  def get_contacts(contact_id)
    return {} if @token.nil? || @token.access_token.nil?
    result = {}
    uri = URI("#{GOOGLE_OAUTH_PATHS["ALL_CONTACTS"]}/#{contact_id}")
    response = FaradayConnections.get(uri.scheme + "://" + uri.host).get do |req|
      req.url "#{uri.path}"
      req.headers["Authorization"] = "OAuth #{@token.access_token}"
    end
    xml_response = REXML::Document.new(response.body)
    xml_response.elements.each("entry") do |single_entity|
      # Remove gd: tag prefixes to just keep logical names
      entity_no_prefixes = single_entity.to_s.gsub(/gd:/, '')
      entity_no_prefixes.gsub!(/gContact:/, '')
      result = Hash.from_xml(entity_no_prefixes)
    end
    result
  end

  def get_all_contacts()
    return {} if @token.nil? || @token.access_token.nil?
    if USE_CACHE
      cached_result = @@contacts_cache.fetch(@user_id)
      return cached_result unless cached_result.nil?
    end
    result = {}
    uri = URI GOOGLE_OAUTH_PATHS["ALL_CONTACTS"]
    response = FaradayConnections.get(uri.scheme + "://" + uri.host).get do |req|
      req.url "#{uri.path}?max-results=2000"
      req.headers["Authorization"] = "OAuth #{@token.access_token}"
    end
    xml_response = REXML::Document.new(response.body)
    xml_response.elements.each("feed/entry") do |single_entity|
      single_entity.elements.each("title") do |name|
        if name.text && !name.text.empty?
          id = single_entity.elements["id"].first.to_s.split("/").last
          if result[name.text]
            result[name.text] << id
          else
            result[name.text] = [id]
          end
        end
      end
    end
    result = Hash[result.sort]
    @@contacts_cache.store(@user_id, result) if USE_CACHE
    result
  end

  def flatten_json_result(contacts_array)
    all_contacts = {}
    contacts_array.each do |contact|
      name = contact["entry"]["title"] unless contact.empty?
      if all_contacts[name]
        current_contact = all_contacts[name]["entry"]
        current_contact.each do |key, value|
          if contact["entry"][key]
            # Decent heuristic for determining which has higher priority (2 emails vs 1)
            # for the purposes of merging contacts. Unfortunately object structure can be nested,
            # so I'm flattening to string for ease of comparison
            contact["entry"][key] = value if contact["entry"][key].to_s.length < value.to_s.length
          else
            contact["entry"][key] = value
          end
        end
      end
      all_contacts[name] = contact
    end
    # Return the hash so that the names are in sorted order
    Hash[all_contacts.sort]
  end

  def get_atom_feed()
    uri = URI GOOGLE_OAUTH_PATHS["GMAIL_ATOM"]
    response = FaradayConnections.get(uri.scheme + "://" + uri.host).get do |req|
      req.url "#{uri.path}/important"
      req.headers["Authorization"] = "OAuth #{@token.access_token}"
    end
    response.body
  end

end
