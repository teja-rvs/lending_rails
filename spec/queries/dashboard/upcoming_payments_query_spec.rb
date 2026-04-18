require "rails_helper"

RSpec.describe Dashboard::UpcomingPaymentsQuery do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    travel_to Date.new(2026, 6, 10).in_time_zone
    example.run
    travel_back
  end

  describe ".call" do
    it "returns 0 when no pending payments in 7-day window" do
      expect(described_class.call).to eq(0)
    end

    it "returns correct count for payments due within 7 days" do
      loan = create(:loan, :active, :with_details)
      create(:payment, :pending, loan: loan, installment_number: 1, due_date: Date.new(2026, 6, 12))
      create(:payment, :pending, loan: loan, installment_number: 2, due_date: Date.new(2026, 6, 15))

      expect(described_class.call).to eq(2)
    end

    it "excludes payments due after 7 days" do
      loan = create(:loan, :active, :with_details)
      create(:payment, :pending, loan: loan, installment_number: 1, due_date: Date.new(2026, 6, 12))
      create(:payment, :pending, loan: loan, installment_number: 2, due_date: Date.new(2026, 6, 25))

      expect(described_class.call).to eq(1)
    end

    it "excludes overdue and completed payments" do
      loan = create(:loan, :active, :with_details)
      create(:payment, :overdue, loan: loan, installment_number: 1, due_date: Date.new(2026, 6, 12))
      create(:payment, :completed, loan: loan, installment_number: 2, due_date: Date.new(2026, 6, 13))
      create(:payment, :pending, loan: loan, installment_number: 3, due_date: Date.new(2026, 6, 14))

      expect(described_class.call).to eq(1)
    end

    it "includes payments due today" do
      loan = create(:loan, :active, :with_details)
      create(:payment, :pending, loan: loan, installment_number: 1, due_date: Date.new(2026, 6, 10))

      expect(described_class.call).to eq(1)
    end
  end
end
