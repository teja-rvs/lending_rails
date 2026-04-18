require "rails_helper"

RSpec.describe Dashboard::OpenApplicationsQuery do
  describe ".call" do
    it "returns 0 when no open or in-progress applications" do
      expect(described_class.call).to eq(0)
    end

    it "counts open and in-progress applications" do
      create(:loan_application)
      create(:loan_application, :in_progress)

      expect(described_class.call).to eq(2)
    end

    it "excludes approved, rejected, and cancelled applications" do
      create(:loan_application)
      create(:loan_application, :approved)
      create(:loan_application, :rejected)
      create(:loan_application, :cancelled)

      expect(described_class.call).to eq(1)
    end
  end
end
