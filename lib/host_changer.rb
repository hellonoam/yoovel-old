# Forces all requests to be secure ones, i.e. over ssl
class HostChanger
  def initialize(app)
    @app = app
  end

  def call(env)
    if env["SERVER_NAME"].include?("herokuapp.com")
      url = Rack::Request.new(env).url
      url.gsub!("yoovel.herokuapp.com", "data.getcorral.com")
      url.gsub!("yoovel-staging.herokuapp.com", "staging-data.getcorral.com")
      [301, { "Location" => url }, []]
    else
      @app.call(env)
    end
  end
end
