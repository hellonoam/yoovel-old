require File.join(Dir.pwd, "lib", "sidecar_search")

class SidecarRegressionAnalysis
  def initialize
    fares = {}
    car = SidecarSearch.new(37.7553, -122.4036)
    10.times do |ii|
      puts "****************************** starting with #{ii} ******************************"
      10.times do |jj|
        i, j = ii + 3, jj + 3
        fares["#{i}, #{j}"] = car.get_fare_calculation(i,j)
      end
    end
    puts fares.map { |k,v| "#{k}, #{v}"}
  end
end

SidecarRegressionAnalysis.new if $0 == __FILE__