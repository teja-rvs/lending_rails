class DocumentUpload < ApplicationRecord
  include DeletionProtection
  STATUSES = %w[active superseded].freeze
  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    image/png
    image/jpeg
    image/gif
    image/webp
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    text/plain
    text/csv
  ].freeze

  belongs_to :documentable, polymorphic: true
  belongs_to :uploaded_by, class_name: "User"
  belongs_to :superseded_by, class_name: "DocumentUpload", optional: true

  has_one_attached :file
  has_paper_trail

  normalizes :file_name, with: ->(value) { value.to_s.squish.presence }
  normalizes :description, with: ->(value) { value.to_s.squish.presence }
  normalizes :status, with: ->(value) { value.to_s.squish.presence&.downcase }

  validates :file_name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :file,
    attached: true,
    content_type: {
      in: ALLOWED_CONTENT_TYPES,
      message: "must be a PDF, image, Word document, spreadsheet, or text file"
    },
    size: { less_than: 10.megabytes, message: "must be less than 10MB" }

  scope :active, -> { where(status: "active") }
  scope :superseded, -> { where(status: "superseded") }
  scope :ordered, -> { order(created_at: :desc) }

  def active?
    status == "active"
  end

  def superseded?
    status == "superseded"
  end
end
