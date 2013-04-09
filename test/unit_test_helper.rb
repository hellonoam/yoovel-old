require File.join(File.dirname(File.dirname(__FILE__)), "lib", "faraday_connections")
require "rr"

module UnitTestHelper

  @@Response = Class.new do
    attr_reader :body
    def initialize(body); @body = body; end
  end

  def stub_request(body)
    stub(FaradayConnections).make_request { @@Response.new(body) }
  end
end