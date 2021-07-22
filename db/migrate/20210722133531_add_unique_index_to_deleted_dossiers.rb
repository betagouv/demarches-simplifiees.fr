class AddUniqueIndexToDeletedDossiers < ActiveRecord::Migration[6.1]
  include Database::MigrationHelpers

  disable_ddl_transaction!

  def up
    delete_duplicates :deleted_dossiers, [:dossier_id]
    add_concurrent_index :deleted_dossiers, [:dossier_id], unique: true
  end

  def down
    remove_index :deleted_dossiers, [:dossier_id]
  end
end
