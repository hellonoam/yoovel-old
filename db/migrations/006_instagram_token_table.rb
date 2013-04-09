Sequel.migration do
  up do
    create_table(:instagram_tokens) do
      primary_key :id
      String :access_token, :null => false
      String :code, :null => false
      Integer :user_id
    end
  end
  down do
    drop_table(:instagram_tokens)
  end
end
