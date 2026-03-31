module Borrowers
  class Create < ApplicationService
    def initialize(attributes)
      @attributes = attributes
    end

    def call
      borrower.tap(&:save)
    rescue ActiveRecord::RecordNotUnique
      borrower.mark_phone_number_taken!
    end

    private
      attr_reader :attributes

      def borrower
        @borrower ||= Borrower.new(attributes)
      end
  end
end
