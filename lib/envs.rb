config_dir = File.join File.dirname(File.dirname(__FILE__)), "config"
require File.join config_dir, "common_environment"
case ENV["RACK_ENV"]
when "production"
  require File.join(config_dir, "prod_environment")
when "staging"
  require File.join(config_dir, "staging_environment")
else
  require File.join(config_dir, "dev_environment")
end