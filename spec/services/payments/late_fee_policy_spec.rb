require "rails_helper"

RSpec.describe Payments::LateFeePolicy do
  describe ".flat_fee_cents" do
    it "returns a positive integer" do
      expect(described_class.flat_fee_cents).to be_a(Integer)
      expect(described_class.flat_fee_cents).to be > 0
    end

    it "returns the MVP flat late fee of ₹25" do
      expect(described_class.flat_fee_cents).to eq(25_00)
    end

    it "is deterministic across repeated calls" do
      first = described_class.flat_fee_cents
      second = described_class.flat_fee_cents

      expect(first).to eq(second)
    end
  end

  describe "MVP_FLAT_LATE_FEE_CENTS" do
    it "is a frozen constant accessible as the single policy value" do
      expect(described_class::MVP_FLAT_LATE_FEE_CENTS).to eq(25_00)
      expect(described_class::MVP_FLAT_LATE_FEE_CENTS).to be_frozen
    end
  end
end
