module Borrowers
  class HistoryQuery < ApplicationQuery
    BLOCKING_APPLICATION_STATUSES = [ "open", "in progress", "approved" ].freeze
    BLOCKING_LOAN_STATUSES = [ "active", "overdue" ].freeze

    Result = Struct.new(
      :borrower,
      :current_context,
      :linked_records,
      :history_state,
      :eligibility,
      :next_step_message,
      keyword_init: true
    )

    CurrentContext = Struct.new(
      :headline,
      :summary,
      :application_count,
      :loan_count,
      keyword_init: true
    )

    LinkedRecord = Struct.new(
      :type,
      :label,
      :identifier,
      :status_label,
      :status_tone,
      :path,
      :relevant_at,
      :relevant_label,
      keyword_init: true
    )

    class HistoryState
      attr_reader :message

      def initialize(empty:, partial:, message:)
        @empty = empty
        @partial = partial
        @message = message
      end

      def empty?
        @empty
      end

      def partial?
        @partial
      end
    end

    class Eligibility
      attr_reader :state, :reason_code, :headline, :message, :next_step_message,
        :blocking_application_count, :blocking_loan_count

      def initialize(state:, reason_code:, headline:, message:, next_step_message:, blocking_application_count:, blocking_loan_count:)
        @state = state
        @reason_code = reason_code
        @headline = headline
        @message = message
        @next_step_message = next_step_message
        @blocking_application_count = blocking_application_count
        @blocking_loan_count = blocking_loan_count
      end

      def eligible?
        state == "eligible"
      end

      def blocked?
        state == "blocked"
      end
    end

    def self.call(...)
      new(...).call
    end

    def initialize(scope: Borrower.all, id:)
      @scope = scope
      @id = id
    end

    def call
      borrower = scope.includes(:loan_applications, loans: :loan_application).find(id)
      applications = ordered_applications_for(borrower)
      loans = ordered_loans_for(borrower)
      eligibility = build_eligibility(applications:, loans:)

      Result.new(
        borrower:,
        current_context: build_current_context(applications:, loans:),
        linked_records: build_linked_records(applications:, loans:),
        history_state: build_history_state(applications:, loans:),
        eligibility:,
        next_step_message: eligibility.next_step_message
      )
    end

    private
      attr_reader :scope, :id

      def ordered_applications_for(borrower)
        borrower.loan_applications.sort_by { |record| [ record.created_at || Time.zone.at(0), record.id ] }.reverse
      end

      def ordered_loans_for(borrower)
        borrower.loans.sort_by { |record| [ record.created_at || Time.zone.at(0), record.id ] }.reverse
      end

      def build_current_context(applications:, loans:)
        blocking_loan_count = loans.count { |loan| BLOCKING_LOAN_STATUSES.include?(loan.status) }
        blocking_application_count = applications.count { |application| BLOCKING_APPLICATION_STATUSES.include?(application.status) }

        CurrentContext.new(
          headline: context_headline(applications:, loans:, blocking_loan_count:, blocking_application_count:),
          summary: context_summary(applications:, loans:, blocking_loan_count:, blocking_application_count:),
          application_count: applications.size,
          loan_count: loans.size
        )
      end

      def build_linked_records(applications:, loans:)
        combined_records = applications.map { |application| linked_application_record(application) } +
          loans.map { |loan| linked_loan_record(loan) }

        combined_records.sort_by { |record| [ record.relevant_at || Time.zone.at(0), record.type, record.identifier ] }.reverse
      end

      def build_history_state(applications:, loans:)
        return HistoryState.new(empty: true, partial: false, message: "No lending history yet. Once applications or loans are created for this borrower, they will appear here in one place.") if applications.empty? && loans.empty?

        if applications.empty? || loans.empty?
          return HistoryState.new(
            empty: false,
            partial: true,
            message: "History exists for this borrower, but some linked context is still limited in this slice. Keep using the protected borrower workspace until the fuller lending workflow arrives."
          )
        end

        HistoryState.new(
          empty: false,
          partial: false,
          message: "Applications and loans are linked here so the borrower record stays readable before the later lending workflows expand."
        )
      end

      def linked_application_record(application)
        LinkedRecord.new(
          type: "application",
          label: "Application",
          identifier: application.application_number,
          status_label: application.status_label,
          status_tone: application.status_tone,
          path: Rails.application.routes.url_helpers.loan_application_path(application),
          relevant_at: application.created_at,
          relevant_label: "Created #{I18n.l(application.created_at.to_date, format: :long)}"
        )
      end

      def linked_loan_record(loan)
        LinkedRecord.new(
          type: "loan",
          label: "Loan",
          identifier: loan.loan_number,
          status_label: loan.status_label,
          status_tone: loan.status_tone,
          path: Rails.application.routes.url_helpers.loan_path(loan),
          relevant_at: loan.created_at,
          relevant_label: "Recorded #{I18n.l(loan.created_at.to_date, format: :long)}"
        )
      end

      def build_eligibility(applications:, loans:)
        blocking_application_count = applications.count { |application| BLOCKING_APPLICATION_STATUSES.include?(application.status) }
        blocking_loan_count = loans.count { |loan| BLOCKING_LOAN_STATUSES.include?(loan.status) }

        if blocking_application_count.positive? && blocking_loan_count.positive?
          return Eligibility.new(
            state: "blocked",
            reason_code: "blocking_application_and_loan",
            headline: "New application blocked",
            message: "A new application cannot be started while another application is still open, in progress, or approved and an active or overdue loan is still linked to this borrower.",
            next_step_message: "Resolve the blocking application and close the active or overdue loan before starting a new one.",
            blocking_application_count:,
            blocking_loan_count:
          )
        end

        if blocking_application_count.positive?
          return Eligibility.new(
            state: "blocked",
            reason_code: "blocking_application",
            headline: "New application blocked",
            message: "A new application cannot be started while another application is still open, in progress, or approved for this borrower.",
            next_step_message: "Wait until the current application is no longer open, in progress, or approved before starting a new one.",
            blocking_application_count:,
            blocking_loan_count:
          )
        end

        if blocking_loan_count.positive?
          return Eligibility.new(
            state: "blocked",
            reason_code: "blocking_loan",
            headline: "New application blocked",
            message: "A new application becomes available only after the active or overdue loan is closed.",
            next_step_message: "Wait until the active or overdue loan is closed before starting a new application.",
            blocking_application_count:,
            blocking_loan_count:
          )
        end

        if applications.any? || loans.any?
          return Eligibility.new(
            state: "eligible",
            reason_code: "eligible_with_history",
            headline: "Eligible for a new application",
            message: eligible_with_history_message(applications:, loans:),
            next_step_message: "This borrower is ready for a new application once that workflow is available. Application creation is introduced in the next story.",
            blocking_application_count:,
            blocking_loan_count:
          )
        end

        Eligibility.new(
          state: "eligible",
          reason_code: "eligible_no_history",
          headline: "Eligible for a new application",
          message: "No active applications or blocking loans are linked to this borrower.",
          next_step_message: "This borrower is ready for a new application once that workflow is available. Application creation is introduced in the next story.",
          blocking_application_count:,
          blocking_loan_count:
        )
      end

      def context_headline(applications:, loans:, blocking_loan_count:, blocking_application_count:)
        return "No lending history yet" if applications.empty? && loans.empty?
        return "Borrower has active lending work" if blocking_loan_count.positive? || blocking_application_count.positive?

        "Borrower has prior lending history"
      end

      def context_summary(applications:, loans:, blocking_loan_count:, blocking_application_count:)
        return "No applications or loans are linked to this borrower yet." if applications.empty? && loans.empty?

        parts = []
        parts << "#{blocking_loan_count} #{'blocking loan'.pluralize(blocking_loan_count)}" if blocking_loan_count.positive?
        parts << "#{blocking_application_count} #{'blocking application'.pluralize(blocking_application_count)}" if blocking_application_count.positive?

        if parts.any?
          "#{parts.to_sentence.capitalize} linked to this borrower today."
        else
          "#{applications.size} #{'application'.pluralize(applications.size)} and #{loans.size} #{'loan'.pluralize(loans.size)} linked to this borrower."
        end
      end

      def eligible_with_history_message(applications:, loans:)
        if applications.any? && loans.empty?
          "This borrower has prior application history, and there is no open, in-progress, or approved application blocking another one."
        elsif loans.any? && applications.empty?
          "This borrower has prior lending history, and all linked loans are closed."
        else
          "This borrower has prior lending history, there is no open, in-progress, or approved application, and all linked loans are closed."
        end
      end
  end
end
