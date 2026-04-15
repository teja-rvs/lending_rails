require "rails_helper"

RSpec.describe Loans::FilteredListQuery do
  describe ".call" do
    it "returns newest-first loans with borrower records eager-loaded" do
      older = create(:loan, loan_number: "LOAN-0001", created_at: Time.zone.parse("2026-04-01 09:00:00"))
      newer = create(:loan, loan_number: "LOAN-0002", created_at: Time.zone.parse("2026-04-02 09:00:00"))

      result = described_class.call.to_a

      expect(result).to eq([ newer, older ])
      expect(result.first.association(:borrower)).to be_loaded
    end

    it "filters loans by a valid lifecycle state" do
      matching = create(:loan, :created, loan_number: "LOAN-0003")
      create(:loan, :active, loan_number: "LOAN-0004")

      result = described_class.call(status: "created")

      expect(result).to contain_exactly(matching)
    end

    it "searches by loan number and borrower name" do
      matching_borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
      matching = create(:loan, borrower: matching_borrower, loan_number: "LOAN-1001")
      create(:loan, loan_number: "LOAN-2002")

      expect(described_class.call(search: "1001")).to contain_exactly(matching)
      expect(described_class.call(search: "asha")).to contain_exactly(matching)
    end

    it "combines status and search filters" do
      matching_borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
      matching = create(:loan, :created, borrower: matching_borrower, loan_number: "LOAN-3001")
      create(:loan, :active, borrower: matching_borrower, loan_number: "LOAN-3002")
      create(:loan, :created, loan_number: "LOAN-4001")

      result = described_class.call(status: "created", search: "asha")

      expect(result).to contain_exactly(matching)
    end
  end
end
