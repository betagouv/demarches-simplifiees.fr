class AddUniqueIndexToChamps < ActiveRecord::Migration[6.1]
  include Database::MigrationHelpers

  disable_ddl_transaction!

  def up
    delete_duplicates :champs, [:type_de_champ_id, :dossier_id, :row]
    add_concurrent_index :champs, [:type_de_champ_id, :dossier_id, :row], unique: true
  end

  def down
    remove_index :champs, [:type_de_champ_id, :dossier_id, :row]
  end
end
