module Loans
  class EvaluateDisbursementReadiness < ApplicationService
    FINANCIAL_DETAIL_ATTRIBUTES = %i[
      principal_amount
      tenure_in_months
      repayment_frequency
      interest_mode
      interest_rate
      total_interest_amount
    ].freeze

    ChecklistItem = Struct.new(:key, :met, :label, :detail, :next_step, keyword_init: true) do
      def met?
        met
      end
    end

    Result = Struct.new(:loan, :items, :blocked_summary, keyword_init: true) do
      def ready_for_disbursement_action?
        items.all?(&:met?)
      end
    end

    def initialize(loan:)
      @loan = loan
    end

    def call
      items = [
        lifecycle_item,
        financial_details_item
      ]

      Result.new(
        loan:,
        items:,
        blocked_summary: blocked_summary_for(items)
      )
    end

    private
      attr_reader :loan

      def lifecycle_item
        case loan.status.to_sym
        when :created
          ChecklistItem.new(
            key: :lifecycle_ready_for_disbursement,
            met: false,
            label: "Loan has reached ready for disbursement",
            detail: "The loan is still in the created stage, so documentation has not been completed yet.",
            next_step: "Begin documentation, complete any remaining loan details, and finish documentation before attempting disbursement."
          )
        when :documentation_in_progress
          ChecklistItem.new(
            key: :lifecycle_ready_for_disbursement,
            met: false,
            label: "Loan has reached ready for disbursement",
            detail: "Documentation is still in progress, so the loan cannot move to disbursement yet.",
            next_step: "Finish any remaining documentation work, then complete documentation to move the loan into Ready for Disbursement."
          )
        when :ready_for_disbursement
          ChecklistItem.new(
            key: :lifecycle_ready_for_disbursement,
            met: true,
            label: "Loan has reached ready for disbursement",
            detail: "Documentation is complete and the loan has reached the Ready for Disbursement stage.",
            next_step: "No action needed."
          )
        else
          ChecklistItem.new(
            key: :lifecycle_ready_for_disbursement,
            met: false,
            label: "Loan has reached ready for disbursement",
            detail: "This loan has already crossed the pre-disbursement boundary, so no further disbursement readiness action is available here.",
            next_step: "Review the loan's current lifecycle state instead of attempting another disbursement handoff."
          )
        end
      end

      def financial_details_item
        financial_errors = financial_detail_errors

        if financial_errors.empty?
          ChecklistItem.new(
            key: :financial_details_complete,
            met: true,
            label: "Required financial details are complete",
            detail: "Principal, tenure, repayment frequency, and interest details satisfy the pre-disbursement validation rules.",
            next_step: "No action needed."
          )
        else
          ChecklistItem.new(
            key: :financial_details_complete,
            met: false,
            label: "Required financial details are complete",
            detail: sentence_with_period(financial_errors.to_sentence),
            next_step: "Update the pre-disbursement loan details so every required financial field is complete and internally consistent."
          )
        end
      end

      def financial_detail_errors
        snapshot = loan.errors.objects.map(&:dup)

        loan.valid?(:details_update)

        messages = FINANCIAL_DETAIL_ATTRIBUTES.filter_map do |attribute|
          formatted_error_for(attribute)
        end

        restore_errors(snapshot)
        messages
      end

      def formatted_error_for(attribute)
        attribute_errors = loan.errors.where(attribute)
        return if attribute_errors.empty?

        preferred_error = attribute_errors.find { |error| error.type == :blank } || attribute_errors.first
        preferred_error.full_message
      end

      def restore_errors(snapshot)
        loan.errors.clear
        snapshot.each { |error| loan.errors.import(error) }
      end

      def sentence_with_period(text)
        text.end_with?(".", "!", "?") ? text : "#{text}."
      end

      def blocked_summary_for(items)
        unmet_items = items.reject(&:met?)
        return if unmet_items.empty?

        reasons = unmet_items.map do |item|
          case item.key
          when :lifecycle_ready_for_disbursement
            "the loan has not reached Ready for Disbursement"
          when :financial_details_complete
            "Required financial details are incomplete"
          else
            item.label
          end
        end

        "Disbursement is blocked because #{reasons.to_sentence}. #{next_step_summary(unmet_items)}"
      end

      def next_step_summary(unmet_items)
        unmet_keys = unmet_items.map(&:key)

        if unmet_keys.include?(:lifecycle_ready_for_disbursement) && unmet_keys.include?(:financial_details_complete)
          "Complete the missing pre-disbursement loan details, then finish the documentation stage before attempting disbursement."
        elsif unmet_keys.include?(:financial_details_complete)
          "Complete the missing pre-disbursement loan details before attempting disbursement."
        else
          unmet_items.first.next_step
        end
      end
  end
end
