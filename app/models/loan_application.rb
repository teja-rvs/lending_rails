class LoanApplication < ApplicationRecord
  STATUSES = [
    "open",
    "in progress",
    "approved",
    "rejected",
    "cancelled"
  ].freeze

  belongs_to :borrower
  has_many :loans, dependent: :restrict_with_exception

  normalizes :application_number, with: ->(value) { value.to_s.squish.presence }
  normalizes :status, with: ->(value) { value.to_s.squish.presence&.downcase }

  validates :application_number, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }

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
end
