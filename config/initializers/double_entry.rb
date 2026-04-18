require "double_entry"

DoubleEntry.configure do |config|
  config.json_metadata = true

  config.define_accounts do |accounts|
    loan_scope = ->(loan) do
      raise "not a Loan" unless loan.instance_of?(Loan)
      loan.id
    end

    accounts.define(identifier: :loan_receivable, scope_identifier: loan_scope, positive_only: true)
    accounts.define(identifier: :disbursement_clearing, scope_identifier: loan_scope)
    accounts.define(identifier: :repayment_received, scope_identifier: loan_scope)
  end

  config.define_transfers do |transfers|
    transfers.define(from: :disbursement_clearing, to: :loan_receivable, code: :disbursement)
    transfers.define(from: :loan_receivable, to: :repayment_received, code: :repayment)
  end
end
