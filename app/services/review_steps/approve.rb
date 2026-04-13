module ReviewSteps
  class Approve < Transition
    private
      def allowed_statuses
        [ "initialized", "waiting for details" ]
      end

      def next_status
        "approved"
      end

      def success_message
        "Review step approved successfully."
      end
  end
end
