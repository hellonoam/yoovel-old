module DistCalc

  RAD_PER_DEG = 0.017453293  #  PI/180
  Rmiles = 3956           # radius of the great circle in miles
  Rkm = 6371              # radius in kilometers...some algorithms use 6367
  Rfeet = Rmiles * 5282   # radius in feet
  Rmeters = Rkm * 1000    # radius in meters

  def self.distance_between_points(lat1, lon1, lat2, lon2)
    # adapted from http://www.codecodex.com/wiki/Calculate_distance_between_two_points_on_a_globe
    lat1, lon1, lat2, lon2 = lat1.to_f, lon1.to_f, lat2.to_f, lon2.to_f
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    dlon_rad = dlon * RAD_PER_DEG
    dlat_rad = dlat * RAD_PER_DEG
    lat1_rad = lat1 * RAD_PER_DEG
    lon1_rad = lon1 * RAD_PER_DEG
    lat2_rad = lat2 * RAD_PER_DEG
    lon2_rad = lon2 * RAD_PER_DEG

    a = Math.sin(dlat_rad/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad/2)**2
    c = 2 * Math.asin( Math.sqrt(a))

    dMi = Rmiles * c          # delta between the two points in miles
    dKm = Rkm * c             # delta in kilometers
    dFeet = Rfeet * c         # delta in feet
    dMeters = Rmeters * c     # delta in meters

    { :miles => dMi, :feet => dFeet }
  end

  def self.distance_formatted(lat1, lon1, lat2, lon2)
    dist = self.distance_between_points(lat1, lon1, lat2, lon2)
    self.format_distance(dist)
  end

  def self.format_distance(dist)
    if dist[:feet] < 200
      { :metric => "feet", :amount => dist[:feet].round(0) }
    else
      { :metric => "miles", :amount => dist[:miles].round(1) }
    end
  end
end