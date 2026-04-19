module Payments
  class MarkCompleted < ApplicationService
    BLOCKED_ALREADY_COMPLETED = "This payment has already been completed.".freeze
    BLOCKED_INVALID_STATE = "This payment cannot be completed from its current state.".freeze
    BLOCKED_OUT_OF_ORDER = "Earlier installments must be completed first.".freeze

    Result = Struct.new(:payment, :error, keyword_init: true) do
      def success?
        error.blank?
      end

      def blocked?
        error.present?
      end
    end

    def initialize(payment:, payment_date:, payment_mode:, notes: nil)
      @payment = payment
      @payment_date = parse_date(payment_date)
      @payment_mode = payment_mode.to_s.squish.downcase.presence
      @notes = notes.presence
    end

    def call
      return blocked(BLOCKED_ALREADY_COMPLETED) if payment.completed?
      return blocked("Payment date is required.") if @payment_date.blank?
      return blocked("Payment date cannot be in the future.") if @payment_date > Date.current
      return blocked("Payment mode is required.") if @payment_mode.blank?
      return blocked("#{@payment_mode} is not a supported payment mode.") unless Payment::PAYMENT_MODES.include?(@payment_mode)

      locked_error = nil

      payment.with_lock do
        payment.reload
        if payment.completed?
          locked_error = BLOCKED_ALREADY_COMPLETED
        elsif !payment.may_mark_completed?
          locked_error = BLOCKED_INVALID_STATE
        elsif earlier_installments_incomplete?
          locked_error = BLOCKED_OUT_OF_ORDER
        else
          payment.payment_date = @payment_date
          payment.payment_mode = @payment_mode
          payment.notes = @notes if @notes
          payment.completed_at = Time.current
          payment.mark_completed!
        end
      end

      return blocked(locked_error) if locked_error

      Result.new(payment: payment)
    rescue AASM::InvalidTransition
      Result.new(payment: payment, error: BLOCKED_INVALID_STATE)
    end

    private
      attr_reader :payment

      def earlier_installments_incomplete?
        payment.loan.payments
          .where("installment_number < ?", payment.installment_number)
          .where.not(status: "completed")
          .exists?
      end

      def blocked(message)
        Result.new(payment: payment, error: message)
      end

      def parse_date(value)
        return value if value.is_a?(Date)

        Date.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end
  end
end
