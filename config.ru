require "resque/server"
require "./yoovel_app"

# TODO: add auth for resque
run Rack::URLMap.new \
  "/"        => YoovelApp.new,
  "/resqued" => Resque::Server.new