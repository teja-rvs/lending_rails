class DocumentsController < ApplicationController
  def create
    @loan = loan_scope.find(params[:loan_id])
    @document_upload = build_document_upload

    result = Documents::Upload.call(
      documentable: @loan,
      file: document_params[:file],
      file_name: document_params[:file_name],
      description: document_params[:description],
      uploaded_by: Current.user
    )

    if result.success?
      redirect_to loan_redirect_path(@loan), notice: "Document '#{result.document_upload.file_name}' uploaded successfully."
    elsif result.blocked?
      redirect_to loan_redirect_path(@loan), alert: result.error
    else
      @document_upload = result.document_upload
      flash.now[:alert] = "Document could not be uploaded."
      render "loans/show", status: :unprocessable_content
    end
  end

  def replace
    @document = DocumentUpload.includes(:documentable).find(params[:id])
    @loan = loan_scope.find(@document.documentable_id)

    result = Documents::ReplaceActiveVersion.call(
      existing_document: @document,
      file: document_params[:file],
      file_name: document_params[:file_name],
      description: document_params[:description],
      uploaded_by: Current.user
    )

    if result.success?
      redirect_to loan_redirect_path(@loan), notice: "Document replaced. Previous version preserved in history."
    elsif result.blocked?
      redirect_to loan_redirect_path(@loan), alert: result.error
    else
      redirect_to loan_redirect_path(@loan), alert: result.document_upload&.errors&.full_messages&.to_sentence || "Document replacement failed."
    end
  end

  private
    def document_params
      params.require(:document).permit(:file, :file_name, :description)
    end

    def loan_scope
      Loan.includes(
        :borrower,
        :loan_application,
        document_uploads: [
          :uploaded_by,
          :superseded_by,
          { file_attachment: :blob }
        ]
      )
    end

    def build_document_upload
      @loan.document_uploads.build(
        file_name: document_params[:file_name],
        description: document_params[:description],
        uploaded_by: Current.user
      )
    end

    def loan_redirect_path(loan)
      if params[:from].present?
        loan_path(loan, from: params[:from])
      else
        loan_path(loan)
      end
    end
end
