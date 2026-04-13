class CreateLoanApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :loan_applications, id: :uuid do |t|
      t.references :borrower, null: false, type: :uuid, foreign_key: true
      t.string :application_number, null: false
      t.string :status, null: false

      t.timestamps
    end

    add_index :loan_applications, :application_number, unique: true
    add_index :loan_applications, :status
  end
end
