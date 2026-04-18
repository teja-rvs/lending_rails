require "rails_helper"

RSpec.describe Dashboard::OverduePaymentsQuery do
  describe ".call" do
    it "returns 0 when no payments exist" do
      expect(described_class.call).to eq(0)
    end

    it "returns correct count when overdue payments exist" do
      create(:payment, :overdue)
      create(:payment, :overdue)

      expect(described_class.call).to eq(2)
    end

    it "excludes pending and completed payments from count" do
      create(:payment, :pending)
      create(:payment, :completed)
      create(:payment, :overdue)

      expect(described_class.call).to eq(1)
    end
  end
end
