class CreateLoans < ActiveRecord::Migration[8.1]
  def change
    create_table :loans, id: :uuid do |t|
      t.references :borrower, null: false, type: :uuid, foreign_key: true
      t.references :loan_application, null: true, type: :uuid, foreign_key: true
      t.string :loan_number, null: false
      t.string :status, null: false

      t.timestamps
    end

    add_index :loans, :loan_number, unique: true
    add_index :loans, :status
  end
end
