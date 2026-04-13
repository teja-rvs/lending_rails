class ReviewStep < ApplicationRecord
  WorkflowDefinition = Struct.new(:step_key, :label, :position, keyword_init: true)

  STATUSES = [
    "initialized",
    "approved",
    "rejected",
    "waiting for details"
  ].freeze
  FINAL_STATUSES = [
    "approved",
    "rejected"
  ].freeze
  WORKFLOW_DEFINITION = [
    WorkflowDefinition.new(step_key: "history_check", label: "History check", position: 1),
    WorkflowDefinition.new(step_key: "phone_screening", label: "Phone screening", position: 2),
    WorkflowDefinition.new(step_key: "verification", label: "Verification", position: 3)
  ].freeze

  belongs_to :loan_application
  has_paper_trail

  normalizes :step_key, with: ->(value) { value.to_s.squish.presence&.downcase }
  normalizes :status, with: ->(value) { value.to_s.squish.presence&.downcase }

  scope :ordered, -> { order(:position) }

  validates :step_key, presence: true, inclusion: { in: WORKFLOW_DEFINITION.map(&:step_key) }, uniqueness: {
    scope: :loan_application_id
  }
  validates :position, presence: true, inclusion: { in: WORKFLOW_DEFINITION.map(&:position) }, uniqueness: {
    scope: :loan_application_id
  }
  validates :status, presence: true, inclusion: { in: STATUSES }

  def self.workflow_definition
    WORKFLOW_DEFINITION
  end

  def self.definition_for(step_key)
    workflow_definition.find { |definition| definition.step_key == step_key.to_s }
  end

  def self.active_for(review_steps)
    ordered_steps = review_steps.to_a.sort_by(&:position)

    ordered_steps.find(&:active_candidate?)
  end

  def label
    self.class.definition_for(step_key)&.label || step_key.to_s.humanize
  end

  def status_label
    status.to_s.split.map(&:capitalize).join(" ")
  end

  def status_tone
    case status
    when "approved"
      :success
    when "rejected"
      :danger
    when "initialized", "waiting for details"
      :warning
    else
      :neutral
    end
  end

  def active_candidate?
    !FINAL_STATUSES.include?(status)
  end

  def final?
    FINAL_STATUSES.include?(status)
  end
end
