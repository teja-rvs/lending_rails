require "rails_helper"

RSpec.describe PaymentsHelper, type: :helper do
  let(:today) { Date.new(2026, 5, 1) }

  describe "#payment_due_hint" do
    it "renders 'Due today' when due_date equals today" do
      payment = build_stubbed(:payment, status: "pending", due_date: today)

      expect(helper.payment_due_hint(payment, today: today)).to eq("Due today")
    end

    it "renders 'Due in N days' when due_date is in the future" do
      payment = build_stubbed(:payment, status: "pending", due_date: today + 3.days)

      expect(helper.payment_due_hint(payment, today: today)).to eq("Due in 3 days")
    end

    it "pluralizes singular future days correctly" do
      payment = build_stubbed(:payment, status: "pending", due_date: today + 1.day)

      expect(helper.payment_due_hint(payment, today: today)).to eq("Due in 1 day")
    end

    it "renders 'Overdue by N days' for past due pending payments" do
      payment = build_stubbed(:payment, status: "pending", due_date: today - 4.days)

      expect(helper.payment_due_hint(payment, today: today)).to eq("Overdue by 4 days")
    end

    it "renders 'Completed on <date>' when the payment is completed with a payment_date" do
      payment = build_stubbed(
        :payment,
        status: "completed",
        due_date: today - 10.days,
        payment_date: today - 2.days,
        payment_mode: "cash",
        completed_at: Time.zone.local(2026, 4, 29, 10)
      )

      expect(helper.payment_due_hint(payment, today: today)).to eq("Completed on #{(today - 2.days).to_fs(:long)}")
    end

    it "falls back to 'Completed' when the payment is completed but payment_date is nil" do
      payment = build_stubbed(
        :payment,
        status: "completed",
        due_date: today - 10.days,
        payment_date: nil,
        payment_mode: nil,
        completed_at: nil
      )

      expect(helper.payment_due_hint(payment, today: today)).to eq("Completed")
    end
  end
end
