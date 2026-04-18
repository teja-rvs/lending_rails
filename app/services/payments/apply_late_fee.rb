module Payments
  class ApplyLateFee < ApplicationService
    BLOCKED_INVALID_STATE = "Late fee could not be applied.".freeze

    Result = Struct.new(:payment, :error, keyword_init: true) do
      def success?
        error.blank?
      end

      def blocked?
        error.present?
      end

      def applied?
        payment.present? && payment.late_fee_cents.to_i.positive? && error.blank?
      end
    end

    def initialize(payment:)
      @payment = payment
    end

    def call
      return Result.new(payment: payment) if no_op?

      payment.with_lock do
        payment.reload
        break if no_op?

        payment.update!(late_fee_cents: Payments::LateFeePolicy.flat_fee_cents)
      end

      Result.new(payment: payment)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("Payments::ApplyLateFee rescued ActiveRecord::RecordInvalid for payment #{payment.id}: #{e.message}")
      blocked(BLOCKED_INVALID_STATE)
    end

    private
      attr_reader :payment

      def no_op?
        payment.late_fee_cents.to_i.positive? || !payment.overdue? || payment.readonly?
      end

      def blocked(message)
        Result.new(payment: payment, error: message)
      end
  end
end
