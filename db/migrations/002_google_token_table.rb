Sequel.migration do
  up do
    create_table(:google_tokens) do
      primary_key :id
      String :access_token, :null => false
      String :code, :null => false
      String :id_token
      String :token_type
      Integer :expires, :null => false
      Integer :user_id
    end
  end
  down do
    drop_table(:google_tokens)
  end
end
