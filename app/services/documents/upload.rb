module Documents
  class Upload < ApplicationService
    Result = Struct.new(:document_upload, :error, keyword_init: true) do
      def success?
        error.blank? && document_upload&.errors&.none?
      end

      def blocked?
        error.present?
      end
    end

    def initialize(documentable:, file:, file_name:, description: nil, uploaded_by:)
      @documentable = documentable
      @file = file
      @file_name = file_name
      @description = description
      @uploaded_by = uploaded_by
    end

    def call
      unless documentable.respond_to?(:documentation_uploadable?) && documentable.documentation_uploadable?
        return Result.new(document_upload: nil, error: "Documents cannot be uploaded to this record in its current state.")
      end

      documentable.with_lock do
        unless documentable.documentation_uploadable?
          return Result.new(document_upload: nil, error: "Documents cannot be uploaded to this record in its current state.")
        end

        document_upload = documentable.document_uploads.build(
          file_name:,
          description:,
          status: "active",
          uploaded_by:
        )
        document_upload.file.attach(file) if file.present?
        document_upload.save

        Result.new(document_upload:)
      end
    end

    private
      attr_reader :documentable, :file, :file_name, :description, :uploaded_by
  end
end
