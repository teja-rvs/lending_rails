require "rails_helper"

RSpec.describe Payments::FilteredListQuery do
  include ActiveSupport::Testing::TimeHelpers

  let(:today) { Date.new(2026, 5, 10) }

  before { travel_to today.in_time_zone }
  after  { travel_back }

  def build_loan(loan_number:, borrower_full_name: nil, phone: nil)
    attrs = { loan_number: loan_number }
    if borrower_full_name
      borrower = create(
        :borrower,
        full_name: borrower_full_name,
        phone_number: phone || "98765 40000"
      )
      attrs[:borrower] = borrower
    end
    create(:loan, :active, :with_details, **attrs)
  end

  describe ".call" do
    it "orders by earliest due_date and eager-loads loan + borrower" do
      loan = build_loan(loan_number: "LOAN-1001")
      earlier = create(:payment, loan:, installment_number: 2, due_date: today + 1.day)
      later = create(:payment, loan:, installment_number: 3, due_date: today + 30.days)
      earliest = create(:payment, loan:, installment_number: 1, due_date: today - 1.day)

      result = described_class.call.to_a

      expect(result).to eq([ earliest, earlier, later ])
      expect(result.first.association(:loan)).to be_loaded
      expect(result.first.loan.association(:borrower)).to be_loaded
    end

    it "orders ties by installment_number ascending" do
      loan = build_loan(loan_number: "LOAN-1002")
      second = create(:payment, loan:, installment_number: 2, due_date: today + 5.days)
      first = create(:payment, loan:, installment_number: 1, due_date: today + 5.days)

      result = described_class.call.to_a

      expect(result).to eq([ first, second ])
    end

    it "filters by canonical pending status" do
      loan = build_loan(loan_number: "LOAN-2001")
      pending = create(:payment, :pending, loan:, installment_number: 1, due_date: today + 5.days)
      create(:payment, :completed, loan:, installment_number: 2, due_date: today + 10.days)

      expect(described_class.call(status: "pending")).to contain_exactly(pending)
    end

    it "filters by canonical completed status" do
      loan = build_loan(loan_number: "LOAN-2002")
      completed = create(:payment, :completed, loan:, installment_number: 1, due_date: today + 1.day)
      create(:payment, :pending, loan:, installment_number: 2, due_date: today + 5.days)

      expect(described_class.call(status: "completed")).to contain_exactly(completed)
    end

    it "filters by canonical overdue status" do
      loan = build_loan(loan_number: "LOAN-2003")
      overdue = create(:payment, :overdue, loan:, installment_number: 1, due_date: today - 5.days)
      create(:payment, :pending, loan:, installment_number: 2, due_date: today + 5.days)

      expect(described_class.call(status: "overdue")).to contain_exactly(overdue)
    end

    it "translates view=upcoming to status=pending" do
      loan = build_loan(loan_number: "LOAN-3001")
      pending = create(:payment, :pending, loan:, installment_number: 1, due_date: today + 1.day)
      create(:payment, :completed, loan:, installment_number: 2, due_date: today + 10.days)

      expect(described_class.call(view: "upcoming")).to contain_exactly(pending)
    end

    it "translates view=overdue to status=overdue" do
      loan = build_loan(loan_number: "LOAN-3002")
      overdue = create(:payment, :overdue, loan:, installment_number: 1, due_date: today - 2.days)
      create(:payment, :pending, loan:, installment_number: 2, due_date: today + 1.day)

      expect(described_class.call(view: "overdue")).to contain_exactly(overdue)
    end

    it "translates view=completed to status=completed" do
      loan = build_loan(loan_number: "LOAN-3003")
      completed = create(:payment, :completed, loan:, installment_number: 1, due_date: today - 3.days)
      create(:payment, :pending, loan:, installment_number: 2, due_date: today + 1.day)

      expect(described_class.call(view: "completed")).to contain_exactly(completed)
    end

    it "prefers explicit status over view alias when both provided" do
      loan = build_loan(loan_number: "LOAN-3004")
      overdue = create(:payment, :overdue, loan:, installment_number: 1, due_date: today - 1.day)
      create(:payment, :pending, loan:, installment_number: 2, due_date: today + 2.days)

      result = described_class.call(view: "upcoming", status: "overdue")

      expect(result).to contain_exactly(overdue)
    end

    it "applies due_window=today only on pending-scoped lists" do
      loan = build_loan(loan_number: "LOAN-4001")
      due_today = create(:payment, :pending, loan:, installment_number: 1, due_date: today)
      create(:payment, :pending, loan:, installment_number: 2, due_date: today + 3.days)

      expect(described_class.call(status: "pending", due_window: "today")).to contain_exactly(due_today)
    end

    it "applies due_window=this_week spanning Monday through Sunday" do
      loan = build_loan(loan_number: "LOAN-4002")
      start_of_week = today.beginning_of_week
      end_of_week = today.end_of_week
      in_week_start = create(:payment, :pending, loan:, installment_number: 1, due_date: start_of_week)
      in_week_end = create(:payment, :pending, loan:, installment_number: 2, due_date: end_of_week)
      create(:payment, :pending, loan:, installment_number: 3, due_date: end_of_week + 1.day)

      result = described_class.call(status: "pending", due_window: "this_week")

      expect(result).to contain_exactly(in_week_start, in_week_end)
    end

    it "applies due_window=next_7_days inclusive of today and seven days forward" do
      loan = build_loan(loan_number: "LOAN-4003")
      in_range = create(:payment, :pending, loan:, installment_number: 1, due_date: today + 7.days)
      out_of_range = create(:payment, :pending, loan:, installment_number: 2, due_date: today + 8.days)

      result = described_class.call(view: "upcoming", due_window: "next_7_days")

      expect(result).to include(in_range)
      expect(result).not_to include(out_of_range)
    end

    it "applies due_window=this_month bounded by beginning_of_month and end_of_month" do
      loan = build_loan(loan_number: "LOAN-4004")
      first_of_month = create(:payment, :pending, loan:, installment_number: 1, due_date: today.beginning_of_month)
      last_of_month = create(:payment, :pending, loan:, installment_number: 2, due_date: today.end_of_month)
      create(:payment, :pending, loan:, installment_number: 3, due_date: today.end_of_month + 1.day)

      result = described_class.call(status: "pending", due_window: "this_month")

      expect(result).to contain_exactly(first_of_month, last_of_month)
    end

    it "ignores due_window when the effective status is not pending" do
      loan = build_loan(loan_number: "LOAN-4005")
      completed_today = create(:payment, :completed, loan:, installment_number: 1, due_date: today)
      completed_next_month = create(:payment, :completed, loan:, installment_number: 2, due_date: today + 40.days)

      result = described_class.call(status: "completed", due_window: "today")

      expect(result).to contain_exactly(completed_today, completed_next_month)
    end

    it "applies due_window=overdue_by_any regardless of status (strictly before today)" do
      loan = build_loan(loan_number: "LOAN-4006")
      yesterday_pending = create(:payment, :pending, loan:, installment_number: 1, due_date: today - 1.day)
      today_pending = create(:payment, :pending, loan:, installment_number: 2, due_date: today)
      future_pending = create(:payment, :pending, loan:, installment_number: 3, due_date: today + 5.days)
      completed_past = create(:payment, :completed, loan:, installment_number: 4, due_date: today - 10.days)

      expect(described_class.call(due_window: "overdue_by_any")).to contain_exactly(yesterday_pending, completed_past)
      expect(described_class.call(view: "overdue", due_window: "overdue_by_any")).to be_empty
      expect(described_class.call(view: "upcoming", due_window: "overdue_by_any")).to contain_exactly(yesterday_pending)

      expect([ today_pending, future_pending ]).to all(be_a(Payment))
    end

    it "excludes a date-overdue pending payment from view=overdue and status=overdue (persisted status wins over date)" do
      loan = build_loan(loan_number: "LOAN-4007")
      create(:payment, :pending, loan:, installment_number: 1, due_date: today - 1.day)

      expect(described_class.call(view: "overdue")).to be_empty
      expect(described_class.call(status: "overdue")).to be_empty
    end

    it "searches by loan number substring" do
      matching_loan = build_loan(loan_number: "LOAN-7777")
      other_loan = build_loan(loan_number: "LOAN-8888")
      matching = create(:payment, loan: matching_loan, installment_number: 1, due_date: today + 1.day)
      create(:payment, loan: other_loan, installment_number: 1, due_date: today + 1.day)

      expect(described_class.call(search: "7777")).to contain_exactly(matching)
    end

    it "searches by borrower name case-insensitively" do
      matching_loan = build_loan(loan_number: "LOAN-9001", borrower_full_name: "Asha Patel", phone: "98765 43210")
      other_loan = build_loan(loan_number: "LOAN-9002", borrower_full_name: "Rahul Singh", phone: "91234 56789")
      matching = create(:payment, loan: matching_loan, installment_number: 1, due_date: today + 1.day)
      create(:payment, loan: other_loan, installment_number: 1, due_date: today + 1.day)

      expect(described_class.call(search: "ASHA")).to contain_exactly(matching)
      expect(described_class.call(search: "asha")).to contain_exactly(matching)
    end

    it "combines view, due_window and search filters" do
      matching_loan = build_loan(loan_number: "LOAN-9101", borrower_full_name: "Asha Patel", phone: "98765 43210")
      other_borrower_loan = build_loan(loan_number: "LOAN-9102", borrower_full_name: "Rahul Singh", phone: "91234 56789")
      matching = create(:payment, :pending, loan: matching_loan, installment_number: 1, due_date: today + 2.days)
      create(:payment, :pending, loan: matching_loan, installment_number: 2, due_date: today + 30.days)
      create(:payment, :pending, loan: other_borrower_loan, installment_number: 1, due_date: today + 2.days)

      result = described_class.call(view: "upcoming", due_window: "next_7_days", search: "asha")

      expect(result).to contain_exactly(matching)
    end

    it "treats invalid status, view, and due_window values as unfiltered" do
      loan = build_loan(loan_number: "LOAN-9201")
      pending = create(:payment, :pending, loan:, installment_number: 1, due_date: today + 1.day)
      completed = create(:payment, :completed, loan:, installment_number: 2, due_date: today + 5.days)

      result = described_class.call(status: "nonsense", view: "nonsense", due_window: "nonsense")

      expect(result).to contain_exactly(pending, completed)
    end
  end
end
