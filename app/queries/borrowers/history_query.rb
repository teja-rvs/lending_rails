module Borrowers
  class HistoryQuery < ApplicationQuery
    Result = Struct.new(
      :borrower,
      :current_context,
      :linked_records,
      :history_state,
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

      Result.new(
        borrower:,
        current_context: build_current_context(applications:, loans:),
        linked_records: build_linked_records(applications:, loans:),
        history_state: build_history_state(applications:, loans:),
        next_step_message: "The next lending step is borrower eligibility review. That workflow is introduced in the next story, so use this page to confirm identity and history before moving on."
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
        active_loan_count = loans.count { |loan| loan.status == "active" }
        open_application_count = applications.count { |application| [ "open", "in progress" ].include?(application.status) }

        CurrentContext.new(
          headline: context_headline(applications:, loans:, active_loan_count:, open_application_count:),
          summary: context_summary(applications:, loans:, active_loan_count:, open_application_count:),
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

      def context_headline(applications:, loans:, active_loan_count:, open_application_count:)
        return "No lending history yet" if applications.empty? && loans.empty?
        return "Borrower has active lending work" if active_loan_count.positive? || open_application_count.positive?

        "Borrower has prior lending history"
      end

      def context_summary(applications:, loans:, active_loan_count:, open_application_count:)
        return "No applications or loans are linked to this borrower yet." if applications.empty? && loans.empty?

        parts = []
        parts << "#{active_loan_count} #{'active loan'.pluralize(active_loan_count)}" if active_loan_count.positive?
        parts << "#{open_application_count} #{'open application'.pluralize(open_application_count)}" if open_application_count.positive?

        if parts.any?
          "#{parts.to_sentence.capitalize} linked to this borrower today."
        else
          "#{applications.size} #{'application'.pluralize(applications.size)} and #{loans.size} #{'loan'.pluralize(loans.size)} linked to this borrower."
        end
      end

  end
end
