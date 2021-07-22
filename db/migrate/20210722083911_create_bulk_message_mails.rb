class CreateBulkMessageMails < ActiveRecord::Migration[6.1]
  def change
    create_table :bulk_messages do |t|
      t.text :body, null: false
      t.integer :dossier_count
      t.string :dossier_state
      t.datetime :sent_at, null: false
      t.bigint :instructeur_id, null: false

      t.timestamps
    end

    create_join_table :bulk_messages, :groupe_instructeurs, column_options: { null: true, foreign_key: true } do |t|
      t.index :bulk_message_id
      t.index :groupe_instructeur_id, name: :index_bulk_messages_groupe_instructeurs_on_gi_id
    end
  end
end
