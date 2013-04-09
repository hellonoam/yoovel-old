Sequel.migration do
  up do
    add_column :google_tokens, :refresh_token, String
  end
  down do
    drop_column :google_tokens, :refresh_token
  end
end
