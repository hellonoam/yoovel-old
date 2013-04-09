Sequel.migration do
  up do
    add_column :users, :instagram_id, Integer
  end
  down do
    drop_column :users, :instagram_id
  end
end
