Sequel.migration do
  up do
    create_table(:facebook_tokens) do
      primary_key :id
      String :access_token, :null => false
      String :code, :null => false
      Integer :expires, :null => false
      Integer :user_id
    end
  end
  down do
    drop_table(:facebook_tokens)
  end
end