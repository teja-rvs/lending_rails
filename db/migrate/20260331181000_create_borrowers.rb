class CreateBorrowers < ActiveRecord::Migration[8.1]
  def change
    create_table :borrowers, id: :uuid do |t|
      t.string :full_name, null: false
      t.string :phone_number, null: false
      t.string :phone_number_normalized, null: false

      t.timestamps
    end

    add_index :borrowers, :full_name
    add_index :borrowers, :phone_number_normalized, unique: true
  end
end
