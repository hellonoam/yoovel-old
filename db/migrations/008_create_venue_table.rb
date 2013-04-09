Sequel.migration do
  up do
    create_table(:venues) do
      primary_key :id
      String :yelp_id # add index here
      String :foursquare_id # and here
      String :foursquare_rating
      String :yelp_rating
      String :address
      Real :lat
      Real :long
      String :name
    end
  end
  down do
    drop_table(:venues)
  end
end
