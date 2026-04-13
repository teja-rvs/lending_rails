module ReviewSteps
  class RequestDetails < Transition
    private
      def allowed_statuses
        [ "initialized" ]
      end

      def next_status
        "waiting for details"
      end

      def success_message
        "Review step marked as waiting for details."
      end
  end
end
