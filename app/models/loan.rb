class Loan < ApplicationRecord
  include AASM

  belongs_to :borrower
  belongs_to :loan_application, optional: true
  has_paper_trail

  normalizes :loan_number, with: ->(value) { value.to_s.squish.presence }
  normalizes :borrower_full_name_snapshot, with: ->(value) { value.to_s.squish.presence }
  normalizes :borrower_phone_number_snapshot, with: ->(value) { value.to_s.squish.presence }
  normalizes :status, with: ->(value) { value.to_s.squish.presence&.downcase }

  validates :loan_number, presence: true, uniqueness: true
  validates :borrower_full_name_snapshot, presence: true
  validates :borrower_phone_number_snapshot, presence: true
  validates :status, presence: true, inclusion: {
    in: ->(loan) { loan.class.aasm.states.map { |state| state.name.to_s } }
  }

  aasm column: :status, whiny_transitions: true do
    state :created, initial: true
    state :documentation_in_progress
    state :ready_for_disbursement
    state :active
    state :overdue
    state :closed

    event :begin_documentation do
      transitions from: :created, to: :documentation_in_progress
    end

    event :complete_documentation do
      transitions from: :documentation_in_progress, to: :ready_for_disbursement
    end

    event :disburse do
      transitions from: :ready_for_disbursement, to: :active
    end

    event :mark_overdue do
      transitions from: :active, to: :overdue
    end

    event :resolve_overdue do
      transitions from: :overdue, to: :active
    end

    event :close do
      transitions from: [ :active, :overdue ], to: :closed
    end
  end

  def self.next_loan_number
    highest_sequence = where("loan_number LIKE ?", "LOAN-%")
      .pluck(:loan_number)
      .filter_map { |value| value.to_s.delete_prefix("LOAN-").to_i if value.to_s.match?(/\ALOAN-\d+\z/) }
      .max

    "LOAN-#{((highest_sequence || 0) + 1).to_s.rjust(4, "0")}"
  end

  def self.create_with_next_loan_number!(**attributes)
    transaction do
      # Serialize sequence allocation so concurrent approvals cannot pick the same loan number.
      connection.execute("LOCK TABLE #{connection.quote_table_name(table_name)} IN EXCLUSIVE MODE")
      create!(**attributes, loan_number: next_loan_number)
    end
  end

  def status_tone
    case aasm.current_state
    when :documentation_in_progress
      :warning
    when :ready_for_disbursement, :active
      :success
    when :overdue
      :danger
    else
      :neutral
    end
  end

  def status_label
    status.to_s.tr("_", " ").split.map(&:capitalize).join(" ")
  end

  def borrower_full_name_display
    borrower_full_name_snapshot.presence || borrower&.full_name
  end

  def borrower_phone_number_display
    borrower_phone_number_snapshot.presence || borrower&.phone_number_normalized
  end

  def next_lifecycle_stage_label
    case aasm.current_state
    when :created
      "Documentation In Progress"
    when :documentation_in_progress
      "Ready For Disbursement"
    when :ready_for_disbursement
      "Active"
    when :active
      "Overdue"
    when :overdue
      "Active"
    else
      "Closed"
    end
  end

  def next_lifecycle_stage_guidance
    case aasm.current_state
    when :created
      "Documentation work is the next controlled step before disbursement readiness can be reviewed."
    when :documentation_in_progress
      "Complete documentation before the loan can move into disbursement readiness."
    when :ready_for_disbursement
      "Disbursement is the next business event that activates the loan."
    when :active
      "An active loan only moves again when repayment behavior creates an overdue condition or closes the account."
    when :overdue
      "Resolve the overdue condition before the loan can return to active servicing or close."
    else
      "This loan has completed its lifecycle and no further transition is expected."
    end
  end
end
