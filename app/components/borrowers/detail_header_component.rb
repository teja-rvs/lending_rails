module Borrowers
  class DetailHeaderComponent < ApplicationComponent
    def initialize(borrower:, current_context:)
      @borrower = borrower
      @current_context = current_context
    end

    attr_reader :borrower, :current_context
  end
end
