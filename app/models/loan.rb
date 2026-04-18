class Loan < ApplicationRecord
  include AASM
  include DeletionProtection

  REPAYMENT_FREQUENCIES = [
    "weekly",
    "bi-weekly",
    "monthly"
  ].freeze
  INTEREST_MODES = [
    "rate",
    "total_interest_amount"
  ].freeze

  belongs_to :borrower
  belongs_to :loan_application, optional: true
  has_many :document_uploads, as: :documentable, dependent: :restrict_with_exception
  has_many :invoices, dependent: :restrict_with_exception
  has_many :payments, dependent: :restrict_with_exception
  has_paper_trail

  monetize :principal_amount_cents, allow_nil: true
  monetize :total_interest_amount_cents, allow_nil: true

  normalizes :loan_number, with: ->(value) { value.to_s.squish.presence }
  normalizes :borrower_full_name_snapshot, with: ->(value) { value.to_s.squish.presence }
  normalizes :borrower_phone_number_snapshot, with: ->(value) { value.to_s.squish.presence }
  normalizes :status, with: ->(value) { value.to_s.squish.presence&.downcase }
  normalizes :repayment_frequency, with: ->(value) { value.to_s.squish.presence&.downcase }
  normalizes :interest_mode, with: ->(value) { value.to_s.squish.presence&.downcase }
  normalizes :notes, with: ->(value) { value.to_s.squish.presence }

  validates :loan_number, presence: true, uniqueness: true
  validates :borrower_full_name_snapshot, presence: true
  validates :borrower_phone_number_snapshot, presence: true
  validates :status, presence: true, inclusion: {
    in: ->(loan) { loan.class.aasm.states.map { |state| state.name.to_s } }
  }
  validates :principal_amount, presence: true, numericality: {
    greater_than: 0
  }, on: :details_update
  validates :tenure_in_months, presence: true, numericality: {
    only_integer: true,
    greater_than: 0
  }, on: :details_update
  validates :repayment_frequency, presence: true, inclusion: {
    in: REPAYMENT_FREQUENCIES
  }, on: :details_update
  validates :interest_mode, presence: true, inclusion: {
    in: INTEREST_MODES
  }, on: :details_update
  validate :validate_interest_details, on: :details_update
  validate :snapshot_fields_immutable, on: :update

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

  def disbursement_invoice
    invoices.disbursement.first
  end

  def payment_invoices
    invoices.payment.ordered
  end

  def disbursed?
    active? || overdue? || closed?
  end

  def has_repayment_schedule?
    payments.exists?
  end

  def total_scheduled_amount
    payments.sum(:total_amount_cents)
  end

  def total_late_fees_cents
    payments.sum(:late_fee_cents)
  end

  def editable_details?
    %i[created documentation_in_progress ready_for_disbursement].include?(aasm.current_state)
  end

  def active_documents
    document_uploads.active.ordered
  end

  def has_documents?
    document_uploads.active.exists?
  end

  def documentation_uploadable?
    editable_details?
  end

  def principal_amount_display
    return "Not provided yet" if principal_amount.blank?

    format("%.2f", principal_amount.to_d)
  end

  def tenure_display
    return "Not provided yet" if tenure_in_months.blank?

    "#{tenure_in_months} months"
  end

  def repayment_frequency_label
    repayment_frequency.to_s.split("-").map(&:capitalize).join("-")
  end

  def interest_mode_label
    case interest_mode
    when "rate"
      "Interest rate"
    when "total_interest_amount"
      "Total interest amount"
    else
      interest_mode.to_s.humanize
    end
  end

  def interest_display
    case interest_mode
    when "rate"
      return "Not provided yet" if interest_rate.blank?

      format("%.4f%%", interest_rate)
    when "total_interest_amount"
      return "Not provided yet" if total_interest_amount.blank?

      format("%.2f", total_interest_amount.to_d)
    else
      "Not provided yet"
    end
  end

  def notes_display
    notes.presence || "Not provided yet"
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

  private
    def snapshot_fields_immutable
      if borrower_full_name_snapshot_changed?
        errors.add(:borrower_full_name_snapshot, "cannot be changed after creation")
      end
      if borrower_phone_number_snapshot_changed?
        errors.add(:borrower_phone_number_snapshot, "cannot be changed after creation")
      end
    end

    def validate_interest_details
      case interest_mode
      when "rate"
        errors.add(:interest_rate, "can't be blank") if interest_rate.blank?
        errors.add(:total_interest_amount, "must be blank when interest mode is rate") if total_interest_amount.present?
      when "total_interest_amount"
        errors.add(:total_interest_amount, "can't be blank") if total_interest_amount.blank?
        errors.add(:interest_rate, "must be blank when interest mode is total interest amount") if interest_rate.present?
      end
    end
end
