require "rails_helper"

RSpec.describe LoanApplications::FilteredListQuery do
  describe ".call" do
    it "returns newest-first applications with borrower records eager-loaded" do
      older = create(:loan_application, application_number: "APP-0001", created_at: Time.zone.parse("2026-04-01 09:00:00"))
      newer = create(:loan_application, application_number: "APP-0002", created_at: Time.zone.parse("2026-04-02 09:00:00"))

      result = described_class.call.to_a

      expect(result).to eq([ newer, older ])
      expect(result.first.association(:borrower)).to be_loaded
    end

    it "filters applications by a valid operational status" do
      matching = create(:loan_application, application_number: "APP-0003", status: "approved")
      create(:loan_application, application_number: "APP-0004", status: "open")

      result = described_class.call(status: "approved")

      expect(result).to contain_exactly(matching)
    end

    it "searches by application number and borrower name" do
      matching_borrower = create(:borrower, full_name: "Asha Patel", phone_number: "98765 43210")
      matching = create(:loan_application, borrower: matching_borrower, application_number: "APP-1001")
      create(:loan_application, application_number: "APP-2002")

      expect(described_class.call(search: "1001")).to contain_exactly(matching)
      expect(described_class.call(search: "asha")).to contain_exactly(matching)
    end
  end
end
