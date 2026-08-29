class FeesController < AdminController
  before_action :authenticate_user!
  before_action :check_admin
  before_action :set_fee, only: [:show, :edit, :update, :destroy]

  # =========================================================
  # INDEX
  # =========================================================

  def index
    @fees = Fee.includes(enrollment: [:user, :course])
               .order(created_at: :desc)

    if params[:search].present?
      search = "%#{params[:search]}%"

      @fees = @fees
        .joins(enrollment: :user)
        .where("users.name ILIKE ?", search)
    end

    @total_fee = @fees.sum(:total_fee)
    @paid_fee  = @fees.sum(:paid_amount)
    @due_fee   = @fees.sum(:due_amount)
  end

  # =========================================================
  # NEW
  # =========================================================

  def new
    @fee = Fee.new
  end

  # =========================================================
  # SHOW
  # =========================================================

  def show
  end

  # =========================================================
  # EDIT
  # =========================================================

  def edit
  end

  # =========================================================
  # GET COURSE FEE
  # =========================================================

  def enrollment_fee
    enrollment = Enrollment.includes(:course).find(params[:enrollment_id])

    render json: {
      fee: enrollment.course.fee.to_d
    }
  end

  # =========================================================
  # CREATE OFFLINE FEE
  # =========================================================

  def create
    enrollment = Enrollment.find(fee_params[:enrollment_id])

    # One Fee record per enrollment
    if enrollment.fee.present?
      redirect_to fees_path,
                  alert: "A fee record already exists for this enrollment."
      return
    end

    @fee = enrollment.build_fee(
      total_fee: enrollment.course.fee,
      paid_amount: fee_params[:paid_amount].presence || 0,
      payment_date: fee_params[:payment_date],
      payment_mode: fee_params[:payment_mode],
      receipt_no: fee_params[:receipt_no]
    )

    calculate_fee_status(@fee)

    if @fee.save
      update_enrollment_status(@fee)

      redirect_to fees_path,
                  notice: "Fee payment recorded successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # =========================================================
  # UPDATE OFFLINE PAYMENT
  # =========================================================

  def update
    new_payment = params.dig(:fee, :paid_amount).to_d

    if new_payment <= 0
      redirect_to edit_fee_path(@fee),
                  alert: "Please enter a valid payment amount."
      return
    end

    remaining_due = @fee.total_fee.to_d - @fee.paid_amount.to_d

    if new_payment > remaining_due
      redirect_to edit_fee_path(@fee),
                  alert: "Payment cannot be greater than the remaining due amount."
      return
    end

    # Add new offline payment
    @fee.paid_amount = @fee.paid_amount.to_d + new_payment

    @fee.payment_date = params.dig(:fee, :payment_date)
    @fee.payment_mode = params.dig(:fee, :payment_mode)
    @fee.receipt_no   = params.dig(:fee, :receipt_no)

    calculate_fee_status(@fee)

    if @fee.save
      update_enrollment_status(@fee)

      redirect_to fees_path,
                  notice: "Fee payment updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # =========================================================
  # DELETE
  # =========================================================

  def destroy
    @fee.destroy

    redirect_to fees_path,
                notice: "Fee record deleted successfully."
  end

  # =========================================================
  # REPORT
  # =========================================================

  def report
    @fees = Fee.includes(enrollment: [:user, :course])

    if params[:month].present?
      begin
        month = Date.parse(params[:month])

        @fees = @fees.where(
          payment_date: month.all_month
        )
      rescue ArgumentError
        # Ignore invalid month
      end
    end

    @total_fee = @fees.sum(:total_fee)
    @paid_fee  = @fees.sum(:paid_amount)
    @due_fee   = @fees.sum(:due_amount)
  end

  # =========================================================
  # EXPORT
  # =========================================================

  def export
    @fees = Fee.includes(enrollment: [:user, :course])

    respond_to do |format|
      format.xlsx
    end
  end

  private

  # =========================================================
  # SET FEE
  # =========================================================

  def set_fee
    @fee = Fee.find(params[:id])
  end

  # =========================================================
  # STRONG PARAMETERS
  # =========================================================

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

  # =========================================================
  # CALCULATE FEE
  # =========================================================

  def calculate_fee_status(fee)
    fee.total_fee = fee.enrollment.course.fee if fee.total_fee.blank?

    fee.paid_amount = fee.paid_amount.to_d

    fee.due_amount =
      fee.total_fee.to_d - fee.paid_amount

    fee.due_amount = 0 if fee.due_amount < 0

    if fee.due_amount.zero?
      fee.status = "Paid"
    elsif fee.paid_amount.positive?
      fee.status = "Partial"
    else
      fee.status = "Due"
    end
  end

  # =========================================================
  # ENROLLMENT STATUS
  # =========================================================

  def update_enrollment_status(fee)
    if fee.status == "Paid"
      fee.enrollment.update!(status: "Approved")
    else
      fee.enrollment.update!(status: "Pending")
    end
  end

  # =========================================================
  # ADMIN CHECK
  # =========================================================

  def check_admin
    redirect_to root_path unless current_user.admin?
  end
end
