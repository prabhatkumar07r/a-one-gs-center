class FeesController < ApplicationController

  before_action :authenticate_user!
  before_action :check_admin
  before_action :set_fee, only: [:show, :edit, :update, :destroy]


  def export
  @fees = Fee.includes(enrollment: [:user, :course])

  respond_to do |format|
    format.xlsx
  end
end

  def report
  @fees = Fee.includes(enrollment: [:user, :course])

  if params[:month].present?
    @fees = @fees.where(
      payment_date: Date.parse(params[:month]).all_month
    )
  end

  @total_fee = @fees.sum(:total_fee)
  @paid_fee  = @fees.sum(:paid_amount)
  @due_fee   = @fees.sum(:due_amount)
end
  def index
    @fees = Fee.includes(enrollment: [:user, :course])
               .order(created_at: :desc)

    if params[:search].present?
      @fees = @fees.joins(enrollment: :user)
                   .where("users.name LIKE ?",
                   "%#{params[:search]}%")
    end

    @total_fee = Fee.sum(:total_fee)
    @paid_fee  = Fee.sum(:paid_amount)
    @due_fee   = Fee.sum(:due_amount)
  end

  def new
    @fee = Fee.new
  end

  def enrollment_fee
  enrollment = Enrollment.find(params[:enrollment_id])

  render json: {
    fee: enrollment.course.fee
  }
end

def create
  @fee = Fee.new(fee_params)

  @fee.total_fee = @fee.enrollment.course.fee
  @fee.due_amount = @fee.total_fee - @fee.paid_amount

  if @fee.due_amount <= 0
    @fee.status = "Paid"
  elsif @fee.paid_amount > 0
    @fee.status = "Partial"
  else
    @fee.status = "Due"
  end

  if @fee.save
    redirect_to fees_path, notice: "Fee added successfully."
  else
    render :new, status: :unprocessable_entity
  end
end

  def show
  end

  def edit
  end
   def update
  new_payment = params[:fee][:paid_amount].to_i

  # Add the new payment to the existing paid amount
  @fee.paid_amount += new_payment

  # Calculate due amount
  @fee.due_amount = @fee.total_fee - @fee.paid_amount

  # Don't allow negative due amount
  @fee.due_amount = 0 if @fee.due_amount < 0

  # Update other fields
  @fee.payment_date = params[:fee][:payment_date]
  @fee.payment_mode = params[:fee][:payment_mode]
  @fee.receipt_no   = params[:fee][:receipt_no]

  # Update status
  if @fee.due_amount == 0
    @fee.status = "Paid"
  elsif @fee.paid_amount > 0
    @fee.status = "Partial"
  else
    @fee.status = "Due"
  end

  if @fee.save
    redirect_to fees_path, notice: "Fee payment updated successfully."
  else
    render :edit, status: :unprocessable_entity
  end
end
  

  def destroy
    @fee.destroy
    redirect_to fees_path, notice: "Fee deleted successfully."
  end

  private

  def set_fee
    @fee = Fee.find(params[:id])
  end

  def fee_params
    params.require(:fee).permit(
      :enrollment_id,
      :total_fee,
      :paid_amount,
      :payment_date,
      :payment_mode,
      :receipt_no
    )
  end

  def check_admin
    redirect_to root_path unless current_user.admin?
  end

end