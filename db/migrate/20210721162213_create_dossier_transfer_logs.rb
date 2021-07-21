class CreateDossierTransferLogs < ActiveRecord::Migration[6.1]
  def change
    create_table :dossier_transfer_logs do |t|
      t.string :from, null: false
      t.string :to, null: false
      t.references :dossier, foreign_key: true, null: false, index: true

      t.timestamps
    end
  end
end
