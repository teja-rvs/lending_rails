module ReviewSteps
  class Transition < ApplicationService
    Result = Struct.new(:loan_application, :review_step, :message, :error, keyword_init: true) do
      def success?
        error.blank?
      end

      def blocked?
        error.present?
      end
    end

    def initialize(loan_application:, review_step_id:)
      @loan_application = loan_application
      @review_step_id = review_step_id
    end

    def call
      loan_application.with_lock do
        return blocked_result("Review steps can no longer be updated after a final decision.") unless loan_application.editable_pre_decision_details?

        workflow_steps = loan_application.review_steps.ordered.lock.to_a
        review_step = workflow_steps.find { |candidate| candidate.id == review_step_id }

        return blocked_result("The selected review step is not available for this application.") if review_step.blank?

        active_step = ReviewStep.active_for(workflow_steps)
        return blocked_result("This review workflow has no active step to update.") if active_step.blank?
        return blocked_result("Only the current active review step can be updated.") unless review_step.id == active_step.id
        return blocked_result(blocked_status_message(review_step)) unless allowed_statuses.include?(review_step.status)

        validation_error = validate_before_transition
        return blocked_result(validation_error) if validation_error.present?

        apply_step_changes(review_step)
        review_step.update!(status: next_status)
        promote_application_status!
        after_step_transition(review_step)
        loan_application.review_steps.reset

        success_result(review_step)
      end
    end

    private
      attr_reader :loan_application, :review_step_id

      def promote_application_status!
        return unless loan_application.status == "open"

        loan_application.update!(status: "in progress")
      end

      def success_result(review_step)
        Result.new(
          loan_application:,
          review_step:,
          message: success_message
        )
      end

      def blocked_result(error)
        Result.new(
          loan_application:,
          error:
        )
      end

      def blocked_status_message(review_step)
        return "This review step has already been completed and cannot be updated." if review_step.final?
        return "This review step is already waiting for details." if review_step.status == "waiting for details"

        "This review step cannot be updated right now."
      end

      def allowed_statuses
        raise NotImplementedError
      end

      def next_status
        raise NotImplementedError
      end

      def success_message
        raise NotImplementedError
      end

      def validate_before_transition
        nil
      end

      def apply_step_changes(_review_step)
      end

      def after_step_transition(_review_step)
      end
  end
end
