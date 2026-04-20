module Loans
  class GenerateRepaymentSchedule < ApplicationService
    Result = Struct.new(:loan, :payments, :error, keyword_init: true) do
      def success?
        error.blank?
      end

      def blocked?
        error.present?
      end
    end

    def initialize(loan:)
      @loan = loan
    end

    def call
      return blocked("Repayment schedules can only be generated for active loans.") unless loan.active?
      return blocked("A repayment schedule already exists for this loan.") if loan.payments.exists?
      return blocked("Loan financial details are incomplete.") unless financial_details_complete?

      due_dates = scheduled_due_dates
      return blocked("Loan financial details are incomplete.") if due_dates.empty?

      total_interest_cents = calculate_total_interest_cents
      return blocked("Loan financial details are invalid.") if total_interest_cents.negative?

      installment_totals = scheduled_installment_totals(
        total_amount_cents: loan.principal_amount_cents + total_interest_cents,
        installment_count: due_dates.size
      )
      return blocked("Repayment schedule cannot be split into positive installments.") if installment_totals.any? { |amount| amount <= 0 }

      payments = create_payments!(
        due_dates:,
        installment_totals:
      )

      Result.new(loan:, payments:)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      return blocked("A repayment schedule already exists for this loan.") if loan.payments.exists?

      raise
    end

    private
      attr_reader :loan

      def blocked(message)
        Result.new(loan:, payments: [], error: message)
      end

      def financial_details_complete?
        loan.disbursement_date.present? &&
          loan.principal_amount_cents.present? &&
          loan.principal_amount_cents.positive? &&
          loan.tenure_in_months.present? &&
          loan.tenure_in_months.positive? &&
          Loan::REPAYMENT_FREQUENCIES.include?(loan.repayment_frequency) &&
          interest_details_complete?
      end

      def interest_details_complete?
        case loan.interest_mode
        when "rate"
          loan.interest_rate.present?
        when "total_interest_amount"
          loan.total_interest_amount_cents.present?
        else
          false
        end
      end

      def calculate_total_interest_cents
        case loan.interest_mode
        when "rate"
          ((loan.principal_amount_cents * loan.interest_rate * loan.tenure_in_months) / (100 * 12)).round
        when "total_interest_amount"
          loan.total_interest_amount_cents
        else
          0
        end
      end

      def scheduled_due_dates
        case loan.repayment_frequency
        when "monthly"
          (1..loan.tenure_in_months).map { |offset| loan.disbursement_date + offset.months }
        when "bi-weekly"
          rolling_due_dates(2.weeks)
        when "weekly"
          rolling_due_dates(1.week)
        else
          []
        end
      end

      def rolling_due_dates(interval)
        due_dates = []
        current_due_date = loan.disbursement_date + interval
        schedule_end_date = loan.disbursement_date + loan.tenure_in_months.months

        while current_due_date <= schedule_end_date
          due_dates << current_due_date
          current_due_date += interval
        end

        due_dates
      end

      def create_payments!(due_dates:, installment_totals:)
        principal_amounts = allocate_component_amounts(
          total_amount_cents: loan.principal_amount_cents,
          installment_totals:
        )

        Payment.transaction(requires_new: Payment.connection.transaction_open?) do
          due_dates.each_with_index.map do |due_date, index|
            installment_number = index + 1
            principal_amount_cents = principal_amounts.fetch(index)
            total_amount_cents = installment_totals.fetch(index)
            interest_amount_cents = total_amount_cents - principal_amount_cents

            Payment.create!(
              loan:,
              installment_number:,
              due_date:,
              principal_amount_cents: principal_amount_cents,
              interest_amount_cents: interest_amount_cents,
              total_amount_cents: total_amount_cents,
              status: "pending"
            )
          end
        end
      end

      def scheduled_installment_totals(total_amount_cents:, installment_count:)
        base_amount_cents = total_amount_cents / installment_count
        rounded_base_cents = (base_amount_cents / 100.0).round(0, half: :even) * 100

        Array.new(installment_count) do |index|
          if index + 1 < installment_count
            rounded_base_cents
          else
            total_amount_cents - (rounded_base_cents * (installment_count - 1))
          end
        end
      end

      def allocate_component_amounts(total_amount_cents:, installment_totals:)
        schedule_total_cents = installment_totals.sum
        allocations = installment_totals.map do |installment_total_cents|
          (total_amount_cents * installment_total_cents) / schedule_total_cents
        end

        remaining_cents = total_amount_cents - allocations.sum
        ranked_indexes = installment_totals.each_index.sort_by do |index|
          [
            -((total_amount_cents * installment_totals.fetch(index)) % schedule_total_cents),
            index
          ]
        end

        ranked_indexes.each do |index|
          break if remaining_cents.zero?
          next unless allocations.fetch(index) < installment_totals.fetch(index)

          allocations[index] += 1
          remaining_cents -= 1
        end

        raise "Unable to allocate installment amounts." unless remaining_cents.zero?

        allocations
      end

  end
end
