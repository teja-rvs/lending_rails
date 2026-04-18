require "rails_helper"

RSpec.describe Dashboard::ActiveLoansQuery do
  describe ".call" do
    it "returns 0 when no active or overdue loans" do
      expect(described_class.call).to eq(0)
    end

    it "counts active and overdue loans" do
      create(:loan, :active, :with_details)
      create(:loan, :overdue, :with_details)

      expect(described_class.call).to eq(2)
    end

    it "excludes created, documentation_in_progress, ready_for_disbursement, and closed loans" do
      create(:loan, :active, :with_details)
      create(:loan, :created)
      create(:loan, :documentation_in_progress)
      create(:loan, :ready_for_disbursement)
      create(:loan, :closed, :with_details)

      expect(described_class.call).to eq(1)
    end
  end
end
