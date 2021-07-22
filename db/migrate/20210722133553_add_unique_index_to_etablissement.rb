class AddUniqueIndexToEtablissement < ActiveRecord::Migration[6.1]
  include Database::MigrationHelpers

  disable_ddl_transaction!

  def up
    delete_duplicates :etablissements, [:dossier_id]
    remove_index :etablissements, [:dossier_id]
    add_concurrent_index :etablissements, [:dossier_id], unique: true
  end

  def down
    remove_index :etablissements, [:dossier_id]
    add_concurrent_index :etablissements, [:dossier_id]
  end
end
