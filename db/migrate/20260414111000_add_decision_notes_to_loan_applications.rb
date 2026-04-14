class AddDecisionNotesToLoanApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :loan_applications, :decision_notes, :text
  end
end
