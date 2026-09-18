class Admin::CouponsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_coupon, only: [:show, :edit, :update, :destroy]

  layout "admin"

  def index
    @coupons = Coupon
      .includes(:course, :student)
      .order(created_at: :desc)
  end

  def show
  end

  def new
    @coupon = Coupon.new(
      coupon_type: "everyone",
      discount_type: "percentage",
      active: true
    )

    load_form_data
  end

  def create
    @coupon = Coupon.new(coupon_params)

    if @coupon.save
      redirect_to admin_coupons_path,
                  notice: "Coupon created successfully."
    else
      load_form_data
      render :new, status: :unprocessable_content
    end
  end

  def edit
    load_form_data
  end

  def update
    if @coupon.update(coupon_params)
      redirect_to admin_coupons_path,
                  notice: "Coupon updated successfully."
    else
      load_form_data
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @coupon.destroy
      redirect_to admin_coupons_path,
                  notice: "Coupon deleted successfully."
    else
      redirect_to admin_coupons_path,
                  alert: @coupon.errors.full_messages.to_sentence
    end
  end

  private

  def set_coupon
    @coupon = Coupon.find(params[:id])
  end

  def load_form_data
    @courses = Course.order(:Course_name)
    @students = User.student.order(:name)
  end

  def coupon_params
    params.require(:coupon).permit(
      :code,
      :course_id,
      :coupon_type,
      :student_id,
      :discount_type,
      :discount_value,
      :usage_limit,
      :expires_at,
      :active
    )
  end

  def require_admin
    redirect_to root_path, alert: "Access Denied" unless current_user.admin?
  end
end