Dir.open(File.dirname(__FILE__)).each do |filename|
  require File.join(File.dirname(__FILE__), filename) if filename =~ /.rb\z/
end
