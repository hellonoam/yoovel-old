require "sequel"
path_to_local_sql = File.join File.dirname(File.expand_path(File.dirname(__FILE__))), "db/dev.sqlite"
DB = Sequel.connect(ENV["DATABASE_URL"] || "sqlite://#{path_to_local_sql}")
