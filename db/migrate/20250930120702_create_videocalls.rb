class CreateVideocalls < ActiveRecord::Migration[7.1]
  def change
    create_table :videocalls do |t|
      t.string :name
      t.string :contact_name
      t.references :conversation, null: false, foreign_key: true
      t.references :account_user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
