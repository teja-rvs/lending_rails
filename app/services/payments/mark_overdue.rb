module Payments
  class MarkOverdue < ApplicationService
    BLOCKED_INVALID_STATE = "Payment is not in a state that can transition to overdue.".freeze

    Result = Struct.new(:payment, :error, keyword_init: true) do
      def success?
        error.blank?
      end

      def blocked?
        error.present?
      end
    end

    def initialize(payment:, today: Date.current)
      @payment = payment
      @today = today.to_date
    end

    def call
      return Result.new(payment: payment) if no_op?
      return blocked(BLOCKED_INVALID_STATE) unless payment.may_mark_overdue?

      payment.with_lock do
        payment.reload
        break if payment.completed? || payment.overdue? || payment.due_date >= @today
        break unless payment.may_mark_overdue?

        payment.mark_overdue!
      end

      Result.new(payment: payment)
    rescue AASM::InvalidTransition => e
      Rails.logger.warn("Payments::MarkOverdue rescued AASM::InvalidTransition for payment #{payment.id} (status=#{payment.status}): #{e.message}")
      Result.new(payment: payment, error: BLOCKED_INVALID_STATE)
    end

    private
      attr_reader :payment

      def no_op?
        payment.completed? || payment.overdue? || payment.due_date >= @today
      end

      def blocked(message)
        Result.new(payment: payment, error: message)
      end
  end
end
