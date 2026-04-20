class LoanApplication < ApplicationRecord
  include DeletionProtection
  STATUSES = [
    "open",
    "in progress",
    "approved",
    "rejected",
    "cancelled"
  ].freeze
  REPAYMENT_FREQUENCIES = [
    "weekly",
    "bi-weekly",
    "monthly"
  ].freeze
  PROPOSED_INTEREST_MODES = [
    "rate",
    "total_interest_amount"
  ].freeze
  FINAL_DECISION_STATUSES = [
    "approved",
    "rejected",
    "cancelled"
  ].freeze

  belongs_to :borrower
  has_many :loans, dependent: :restrict_with_exception
  has_many :review_steps, -> { order(:position) }, dependent: :restrict_with_exception
  has_paper_trail

  monetize :requested_amount_cents, allow_nil: true

  before_validation :assign_application_number, on: :create

  normalizes :application_number, with: ->(value) { value.to_s.squish.presence }
  normalizes :borrower_full_name_snapshot, with: ->(value) { value.to_s.squish.presence }
  normalizes :borrower_phone_number_snapshot, with: ->(value) { value.to_s.squish.presence }
  normalizes :decision_notes, with: ->(value) { value.to_s.squish.presence }
  normalizes :request_notes, with: ->(value) { value.to_s.squish.presence }
  normalizes :status, with: ->(value) { value.to_s.squish.presence&.downcase }
  normalizes :requested_repayment_frequency, with: ->(value) { value.to_s.squish.presence&.downcase }
  normalizes :proposed_interest_mode, with: ->(value) { value.to_s.squish.presence&.downcase }

  validates :application_number, presence: true, uniqueness: true
  validates :borrower_full_name_snapshot, presence: true
  validates :borrower_phone_number_snapshot, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :requested_amount, presence: true, numericality: {
    greater_than: 0
  }, on: :details_update
  validates :requested_tenure_in_months, presence: true, numericality: {
    only_integer: true,
    greater_than: 0
  }, on: :details_update
  validates :requested_repayment_frequency, presence: true, inclusion: {
    in: REPAYMENT_FREQUENCIES
  }, on: :details_update
  validates :proposed_interest_mode, presence: true, inclusion: {
    in: PROPOSED_INTEREST_MODES
  }, on: :details_update
  validate :snapshot_fields_immutable, on: :update

  def self.next_application_number
    highest_sequence = where("application_number LIKE ?", "APP-%")
      .pluck(:application_number)
      .filter_map { |value| value.to_s.delete_prefix("APP-").to_i if value.to_s.match?(/\AAPP-\d+\z/) }
      .max

    "APP-#{((highest_sequence || 0) + 1).to_s.rjust(4, "0")}"
  end

  def self.create_with_next_application_number!(**attributes)
    transaction do
      connection.execute("LOCK TABLE #{connection.quote_table_name(table_name)} IN EXCLUSIVE MODE")
      create!(**attributes, application_number: next_application_number)
    end
  end

  def status_tone
    case status
    when "approved"
      :success
    when "rejected", "cancelled"
      :danger
    when "open", "in progress"
      :warning
    else
      :neutral
    end
  end

  def status_label
    status.to_s.split.map(&:capitalize).join(" ")
  end

  def editable_pre_decision_details?
    !FINAL_DECISION_STATUSES.include?(status)
  end

  def borrower_full_name_display
    borrower_full_name_snapshot.presence || borrower&.full_name
  end

  def borrower_phone_number_display
    borrower_phone_number_snapshot.presence || borrower&.phone_number_normalized
  end

  def decision_notes_display
    decision_notes.presence || "No decision notes recorded"
  end

  def all_review_steps_approved?
    if review_steps.loaded?
      review_steps.any? && review_steps.all? { |review_step| review_step.status == "approved" }
    else
      review_steps.exists? && review_steps.where.not(status: "approved").none?
    end
  end

  def approvable?
    status == "in progress" && all_review_steps_approved?
  end

  def rejectable?
    !FINAL_DECISION_STATUSES.include?(status)
  end

  def cancellable?
    !FINAL_DECISION_STATUSES.include?(status)
  end

  def active_review_step
    ReviewStep.active_for(review_steps)
  end

  def pre_decision_details_complete?
    requested_amount.present? &&
      requested_tenure_in_months.present? &&
      requested_repayment_frequency.present? &&
      proposed_interest_mode.present?
  end

  def loan
    return loans.first if association(:loans).loaded?

    loans.order(:created_at).first
  end

  def requested_repayment_frequency_label
    requested_repayment_frequency.to_s.split("-").map(&:capitalize).join("-")
  end

  def proposed_interest_mode_label
    case proposed_interest_mode
    when "rate"
      "Interest rate"
    when "total_interest_amount"
      "Total interest amount"
    else
      proposed_interest_mode.to_s.humanize
    end
  end

  def requested_amount_display
    return "Not provided yet" if requested_amount.blank?

    format("%.2f", requested_amount.to_d)
  end

  def requested_amount_form_value
    return if requested_amount.blank?

    requested_amount_display
  end

  def requested_tenure_display
    return "Not provided yet" if requested_tenure_in_months.blank?

    "#{requested_tenure_in_months} months"
  end

  def request_notes_display
    request_notes.presence || "Not provided yet"
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

    def assign_application_number
      self.application_number ||= self.class.next_application_number
    end
end
