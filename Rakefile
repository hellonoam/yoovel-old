require 'resque/tasks'
require 'rake/testtask'
require File.join(Dir.pwd, "redis", "venue_jobs")
require File.join(Dir.pwd, "lib", "envs")

Rake::TestTask.new do |t|
  t.name = "test:integrations"
  t.verbose = true
  t.test_files = FileList['test/integrations/*.rb']
end

Rake::TestTask.new do |t|
  t.name = "test:units"
  t.verbose = true
  t.test_files = FileList['test/units/*.rb']
end

Rake::TestTask.new do |t|
  t.name = "test"
  t.verbose = true
  t.test_files = FileList['test/units/*.rb', 'test/integrations/*.rb']
end

task "resque:setup" do
  uri = URI.parse(REDIS_URL)
  Resque.redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  ENV['QUEUE'] = '*'
  Resque.before_fork = Proc.new { DB.disconnect }
end

task "jobs:work" => "resque:work"