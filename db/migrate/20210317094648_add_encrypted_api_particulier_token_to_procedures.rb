class AddEncryptedAPIParticulierTokenToProcedures < ActiveRecord::Migration[6.0]
  def change
    add_column :procedures, :encrypted_api_particulier_token, :string
  end
end
