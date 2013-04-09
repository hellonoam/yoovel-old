Sequel.migration do
  up do
    add_column :users, :facebook_id, Integer
  end
  down do
    drop_column :users, :facebook_id
  end
end
