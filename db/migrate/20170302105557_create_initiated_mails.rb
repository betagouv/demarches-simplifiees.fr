class CreateInitiatedMails < ActiveRecord::Migration[5.2]
  def change
    create_table :initiated_mails do |t|
      t.string :object
      t.text :body
      t.belongs_to :procedure, index: true, unique: true, foreign_key: true

      t.timestamps
    end
  end
end
