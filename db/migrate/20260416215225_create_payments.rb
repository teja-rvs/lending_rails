class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :loan, type: :uuid, null: false, foreign_key: true
      t.integer :installment_number, null: false
      t.date :due_date, null: false
      t.bigint :principal_amount_cents, null: false
      t.bigint :interest_amount_cents, null: false
      t.bigint :total_amount_cents, null: false
      t.string :status, null: false, default: "pending"
      t.date :payment_date
      t.string :payment_mode
      t.bigint :late_fee_cents, null: false, default: 0
      t.datetime :completed_at
      t.text :notes

      t.timestamps
    end

    add_index :payments, :status
    add_index :payments, :due_date
    add_index :payments, [ :loan_id, :installment_number ], unique: true
  end
end
