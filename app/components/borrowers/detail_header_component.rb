module Borrowers
  class DetailHeaderComponent < ApplicationComponent
    def initialize(borrower:, current_context:, eligibility:)
      @borrower = borrower
      @current_context = current_context
      @eligibility = eligibility
    end

    attr_reader :borrower, :current_context, :eligibility

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
  end
end
