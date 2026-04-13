class AddPreDecisionFieldsToLoanApplications < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :loan_applications, :requested_amount_cents, :bigint
    add_column :loan_applications, :requested_tenure_in_months, :integer
    add_column :loan_applications, :requested_repayment_frequency, :string
    add_column :loan_applications, :proposed_interest_mode, :string
    add_column :loan_applications, :request_notes, :text
    add_column :loan_applications, :borrower_full_name_snapshot, :string
    add_column :loan_applications, :borrower_phone_number_snapshot, :string

    add_index :loan_applications, :requested_repayment_frequency, algorithm: :concurrently
    add_index :loan_applications, :proposed_interest_mode, algorithm: :concurrently
  end
end
