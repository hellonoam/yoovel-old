require "faraday"
require "lrucache"
require "active_support/core_ext"

class FaradayConnections

  DEFAULT_TTL = 3.hours

  @@request_cache = LRUCache.new(:ttl => DEFAULT_TTL, :max_size => 10000)

  @@connections = Hash.new do |hash, key|
    hash[key] = Faraday.new(:url => key) do |faraday|
      faraday.request  :url_encoded
      faraday.response :logger
      faraday.adapter  :em_synchrony
    end
  end

  def self.get(url)
    @@connections[url]
  end

  def self.post(uri, body, ttl = 0.seconds)
    connection = get(uri.scheme + "://" + uri.host)
    connection.post do |req|
      req.url "#{uri.path}?#{uri.query}"
      req.body = body unless body.nil?
    end
  end

  def self.make_request(uri, set_encoding_header = true, body = nil, user_agent = nil, auth = nil)
    connection = get(uri.scheme + "://" + uri.host)
    headers = {}
    headers["Accept-Encoding"] = "deflate" if set_encoding_header
    headers["User-Agent"] = user_agent unless user_agent.nil?
    headers["Authorization"] = auth unless auth.nil?
    connection.headers = headers
    connection.get do |req|
      req.url "#{uri.path}?#{uri.query}"
      req.body = body unless body.nil?
    end
  end

  def self.make_request_through_cache(uri, ttl = DEFAULT_TTL, set_encoding_header = true, body = nil,
      user_agent = nil, auth = nil)
    response = @@request_cache.fetch(uri.to_s + body.to_s)
    unless response.nil?
      puts "got response from cache for #{uri}"
      return response
    end
    response = make_request(uri, set_encoding_header, body, user_agent, auth)
    @@request_cache.store(uri.to_s + body.to_s, response, ttl)
    response
  end

end