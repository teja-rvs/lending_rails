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
      expect(result.current_context.summary).to include("1 active loan")
      expect(result.current_context.summary).to include("2 open applications")
      expect(result.history_state.empty?).to be(false)
      expect(result.history_state.partial?).to be(false)
    end

    it "flags partial history when only one linked record type exists" do
      borrower = create(:borrower)
      create(:loan_application, borrower:, application_number: "APP-0001", status: "open")

      result = described_class.call(id: borrower.id)

      expect(result.history_state.empty?).to be(false)
      expect(result.history_state.partial?).to be(true)
      expect(result.history_state.message).to match(/some linked context is still limited/i)
    end

    it "returns a calm empty state when no lending records exist yet" do
      borrower = create(:borrower)

      result = described_class.call(id: borrower.id)

      expect(result.linked_records).to be_empty
      expect(result.history_state.empty?).to be(true)
      expect(result.current_context.headline).to eq("No lending history yet")
    end
  end
end
