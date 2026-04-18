module Loans
  class RefreshStatus < ApplicationService
    BLOCKED_INVALID_STATE = "Loan is not in a state that can refresh its overdue status.".freeze

    Result = Struct.new(:loan, :transitioned, :error, keyword_init: true) do
      def success?
        error.blank?
      end

      def blocked?
        error.present?
      end

      def changed?
        transitioned.present?
      end
    end

    def initialize(loan:, today: Date.current)
      @loan = loan
      @today = today.to_date
    end

    def call
      return Result.new(loan: loan, transitioned: nil) unless loan.disbursed?
      return Result.new(loan: loan, transitioned: nil) if loan.closed?

      transitioned = nil

      loan.with_lock do
        loan.payments.ordered.each do |payment|
          next unless payment.pending? && payment.due_date < @today

          Payments::MarkOverdue.call(payment: payment, today: @today)
        end

        loan.payments.reload

        if loan.active? && loan.payments.any?(&:overdue?)
          loan.mark_overdue!
          transitioned = :mark_overdue
        elsif loan.overdue? && loan.payments.none? { |p| p.overdue? || (p.pending? && p.due_date < @today) }
          loan.resolve_overdue!
          transitioned = :resolve_overdue
        end
      end

      Result.new(loan: loan, transitioned: transitioned)
    rescue AASM::InvalidTransition => e
      Rails.logger.warn("Loans::RefreshStatus rescued AASM::InvalidTransition for loan #{loan.id} (status=#{loan.status}): #{e.message}")
      Result.new(loan: loan, transitioned: nil, error: BLOCKED_INVALID_STATE)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("Loans::RefreshStatus rescued ActiveRecord::RecordInvalid for loan #{loan.id}: #{e.message}")
      Result.new(loan: loan, transitioned: nil, error: BLOCKED_INVALID_STATE)
    end

    private
      attr_reader :loan
  end
end
