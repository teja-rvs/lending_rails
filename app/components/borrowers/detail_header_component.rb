module Borrowers
  class DetailHeaderComponent < ApplicationComponent
    def initialize(borrower:, current_context:, eligibility:, start_application_path: nil)
      @borrower = borrower
      @current_context = current_context
      @eligibility = eligibility
      @start_application_path = start_application_path
    end

    attr_reader :borrower, :current_context, :eligibility, :start_application_path

    def eligibility_panel_classes
      if eligibility.eligible?
        "border-emerald-200 bg-emerald-50"
      else
        "border-amber-200 bg-amber-50"
      end
    end

    def eligibility_badge_classes
      if eligibility.eligible?
        "border-emerald-200 bg-white text-emerald-700"
      else
        "border-amber-200 bg-white text-amber-700"
      end
    end

    def eligibility_badge_label
      eligibility.eligible? ? "Eligible" : "Blocked"
    end

    def show_start_application?
      eligibility.eligible? && start_application_path.present?
    end
  end
end
