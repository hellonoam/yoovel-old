require "text"

module Whitelist

  @discovery_terms = ["thai", "italian", "mexican", "taco", "burger", "burgers", "salad", "sandwhich",
                     "steak", "steakhouse", "american", "chinese", "vietnamese", "indian", "vegetarian",
                     "vegan", "greek", "mediterranean", "sushi", "japanese", "french", "peruvian", "cajun",
                     "pizza", "brunch", "lunch", "dinner", "bars", "bar", "drinks"]

  def self.in_discovery_whitelist(query)
    # Remove keywords like "food" or "restaurant" from the query to clean it
    # Arbitrarily (for now), let's tolerate a lichtenstein distance of two, to accomodate
    # typos
    query = query.downcase
    query = query.split(" ")
    query.delete("restaurant")
    query.delete("food")
    query = query.join(" ")
    @discovery_terms.each do |discovery_term|
      if Text::Levenshtein.distance(query, discovery_term) <= 2
        return true
      end
    end
    return false
  end
end
