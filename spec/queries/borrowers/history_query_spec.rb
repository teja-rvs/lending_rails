require "rails_helper"

RSpec.describe Borrowers::HistoryQuery do
  describe ".call" do
    it "returns linked records in deterministic newest-first order across applications and loans" do
      borrower = create(:borrower)
      create(:loan_application, borrower:, application_number: "APP-0001", status: "open", created_at: Time.zone.parse("2026-04-01 09:00:00"))
      create(:loan, borrower:, loan_number: "LOAN-0001", status: "closed", created_at: Time.zone.parse("2026-04-02 09:00:00"))
      create(:loan_application, borrower:, application_number: "APP-0002", status: "in progress", created_at: Time.zone.parse("2026-04-03 09:00:00"))
      create(:loan, borrower:, loan_number: "LOAN-0002", status: "active", created_at: Time.zone.parse("2026-04-04 09:00:00"))

      result = described_class.call(id: borrower.id)

      expect(result.borrower).to eq(borrower)
      expect(result.linked_records.map(&:identifier)).to eq([ "LOAN-0002", "APP-0002", "LOAN-0001", "APP-0001" ])
      expect(result.current_context.summary).to include("1 blocking loan")
      expect(result.current_context.summary).to include("2 blocking applications")
      expect(result.history_state.empty?).to be(false)
      expect(result.history_state.partial?).to be(false)
      expect(result.eligibility.reason_code).to eq("blocking_application_and_loan")
      expect(result.eligibility.message).to include("open, in progress, or approved")
      expect(result.eligibility.message).to include("active or overdue loan")
    end

    it "returns a stable blocked reason when an active application is the only blocker" do
      borrower = create(:borrower)
      create(:loan_application, borrower:, application_number: "APP-0001", status: "open")

      result = described_class.call(id: borrower.id)

      expect(result.eligibility.state).to eq("blocked")
      expect(result.eligibility.reason_code).to eq("blocking_application")
      expect(result.eligibility.message).to include("open, in progress, or approved")
      expect(result.history_state.empty?).to be(false)
      expect(result.history_state.partial?).to be(true)
    end

    it "treats an approved application as a blocking application state" do
      borrower = create(:borrower)
      create(:loan_application, borrower:, application_number: "APP-0002", status: "approved")

      result = described_class.call(id: borrower.id)

      expect(result.eligibility.state).to eq("blocked")
      expect(result.eligibility.reason_code).to eq("blocking_application")
      expect(result.eligibility.message).to include("open, in progress, or approved")
    end

    it "returns an eligible state when prior loans are closed and no blocking application exists" do
      borrower = create(:borrower)
      create(:loan, borrower:, loan_number: "LOAN-0001", status: "closed")

      result = described_class.call(id: borrower.id)

      expect(result.eligibility.state).to eq("eligible")
      expect(result.eligibility.reason_code).to eq("eligible_with_history")
      expect(result.eligibility.message).to include("all linked loans are closed")
    end

    it "treats an overdue loan as a blocking loan state" do
      borrower = create(:borrower)
      create(:loan, borrower:, loan_number: "LOAN-0003", status: "overdue")

      result = described_class.call(id: borrower.id)

      expect(result.eligibility.state).to eq("blocked")
      expect(result.eligibility.reason_code).to eq("blocking_loan")
      expect(result.eligibility.message).to include("active or overdue loan")
    end

    it "returns accurate eligible history copy when only non-blocking applications exist" do
      borrower = create(:borrower)
      create(:loan_application, borrower:, application_number: "APP-0003", status: "cancelled")

      result = described_class.call(id: borrower.id)

      expect(result.eligibility.state).to eq("eligible")
      expect(result.eligibility.reason_code).to eq("eligible_with_history")
      expect(result.eligibility.message).to include("prior application history")
      expect(result.eligibility.message).not_to include("all linked loans are closed")
    end

    it "returns a calm eligible empty state when no lending records exist yet" do
      borrower = create(:borrower)

      result = described_class.call(id: borrower.id)

      expect(result.linked_records).to be_empty
      expect(result.history_state.empty?).to be(true)
      expect(result.current_context.headline).to eq("No lending history yet")
      expect(result.eligibility.state).to eq("eligible")
      expect(result.eligibility.reason_code).to eq("eligible_no_history")
      expect(result.next_step_message).to include("Start a new application")
    end
  end
end
