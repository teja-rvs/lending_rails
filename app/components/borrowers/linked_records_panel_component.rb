module Borrowers
  class LinkedRecordsPanelComponent < ApplicationComponent
    def initialize(linked_records:, history_state:, next_step_message:)
      @linked_records = linked_records
      @history_state = history_state
      @next_step_message = next_step_message
    end

    attr_reader :linked_records, :history_state, :next_step_message
  end
end
