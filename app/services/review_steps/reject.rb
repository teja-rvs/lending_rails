module ReviewSteps
  class Reject < Transition
    def initialize(loan_application:, review_step_id:, rejection_note:)
      super(loan_application:, review_step_id:)
      @rejection_note = rejection_note.to_s.squish.presence
    end

    private
      attr_reader :rejection_note

      def allowed_statuses
        [ "initialized", "waiting for details" ]
      end

      def next_status
        "rejected"
      end

      def success_message
        "Review step rejected. Application has been rejected."
      end

      def apply_step_changes(review_step)
        review_step.rejection_note = rejection_note
      end

      def after_step_transition(_review_step)
        loan_application.update!(status: "rejected", decision_notes: rejection_note)
      end

      def validate_before_transition
        if rejection_note.blank?
          return "A rejection note is required when rejecting a review step."
        end
        nil
      end
  end
end
