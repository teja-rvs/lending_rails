module Documents
  class ReplaceActiveVersion < ApplicationService
    Result = Struct.new(:document_upload, :error, keyword_init: true) do
      def success?
        error.blank? && document_upload&.errors&.none?
      end

      def blocked?
        error.present?
      end
    end

    def initialize(existing_document:, file:, file_name: nil, description: nil, uploaded_by:)
      @existing_document = existing_document
      @file = file
      @file_name = file_name
      @description = description
      @uploaded_by = uploaded_by
    end

    def call
      return Result.new(document_upload: nil, error: "This document has already been superseded.") if existing_document.superseded?

      unless documentable.respond_to?(:documentation_uploadable?) && documentable.documentation_uploadable?
        return Result.new(document_upload: nil, error: "Documents cannot be modified on this record in its current state.")
      end

      documentable.with_lock do
        return Result.new(document_upload: nil, error: "This document has already been superseded.") if existing_document.reload.superseded?

        unless documentable.documentation_uploadable?
          return Result.new(document_upload: nil, error: "Documents cannot be modified on this record in its current state.")
        end

        new_document = documentable.document_uploads.build(
          file_name: file_name.presence || existing_document.file_name,
          description: description.presence || existing_document.description,
          status: "active",
          uploaded_by:
        )
        new_document.file.attach(file) if file.present?

        ActiveRecord::Base.transaction do
          if new_document.save
            existing_document.update!(
              status: "superseded",
              superseded_at: Time.current,
              superseded_by: new_document
            )
          else
            raise ActiveRecord::Rollback
          end
        end

        Result.new(document_upload: new_document)
      end
    end

    private
      attr_reader :existing_document, :file, :file_name, :description, :uploaded_by

      def documentable
        existing_document.documentable
      end
  end
end
