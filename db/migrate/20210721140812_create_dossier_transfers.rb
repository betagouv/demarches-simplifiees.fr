class CreateDossierTransfers < ActiveRecord::Migration[6.1]
  def change
    create_table :dossier_transfers do |t|
      t.string :token, null: false
      t.string :email, null: false

      t.timestamps
    end

    add_reference :dossiers, :dossier_transfer, foreign_key: true, null: true, index: true
  end
end
