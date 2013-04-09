require "lrucache"
require "json"
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "faraday_connections")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "yelp_search")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "founders_choice")

# Placeholder class. If we see this category get selected, we should consider actually buildilng
# an API out for SFEater
class SFEater < FoundersChoice

  def initialize(lat, long)
    @lat, @long = lat, long
    @sf_lat = 37.7829
    @sf_long = -122.4084
    yelp_ids = ["nopa", "frances", "lers-ros-thai", "bar-tartine", "ichi-sushi", "spqr", "aziza",
             "tonys-pizza-napoletana", "namu-gaji", "gitane-san-francisco-2", "aq-restaurant-and-bar",
             "wayfare-tavern-san-francisco-2", "bar-agricole", "tacolicious", "zare-at-fly-trap", 
             "the-alembic", "range", "perbacco", "foreign-cinema", "super-duper-burgers-san-francisco-4",
             "flour-water", "mission-chinese-food-san-francisco-4",
             "absinthe-brasserie-and-bar-san-francisco-2", "la-taqueria-san-francisco-2", "la-ciccia",
             "pizzeria-delfina", "la-torta-gorda", "outerlands", "zuni-cafe", "izakaya-sozai", "bar-crudo",
             "benu-san-francisco-4", "state-bird-provisions", "yank-sing-san-francisco-2",
             "cotogna", "bix", "swan-oyster-depot", "leopolds-san-francisco-2"]

    @@sfeater_venue_data ||= get_top_restaurants(yelp_ids)
  end

  def recommendations
    @@sfeater_venue_data
  end

end
