class BorrowersController < ApplicationController
  def index
    @search_query = params[:q].to_s.squish
    @borrowers = Borrowers::LookupQuery.call(search: @search_query)
    @has_borrowers = Borrower.exists?
  end

  def new
    @borrower = Borrower.new
  end

  def create
    @borrower = Borrowers::Create.call(borrower_params)

    if @borrower.persisted?
      redirect_to borrower_path(@borrower), notice: "Borrower created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @borrower = Borrower.find(params[:id])
  end

  private
    def borrower_params
      params.require(:borrower).permit(:full_name, :phone_number)
    end
end
