class AddFinancialDetailsToLoans < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      change_table :loans, bulk: true do |t|
        t.bigint :principal_amount_cents
        t.integer :tenure_in_months
        t.string :repayment_frequency
        t.string :interest_mode
        t.decimal :interest_rate, precision: 8, scale: 4
        t.bigint :total_interest_amount_cents
        t.date :disbursement_date
        t.text :notes
      end

      add_index :loans, :repayment_frequency
      add_index :loans, :interest_mode
    end
  end
end
