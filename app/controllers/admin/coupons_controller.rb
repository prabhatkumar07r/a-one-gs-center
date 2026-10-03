class Admin::CouponsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_coupon, only: [:show, :edit, :update, :destroy]

  layout "admin"
def index
  @coupons = Coupon
    .includes(:course, :test_series, :ebook, :student)
    .order(created_at: :desc)
end

  def show
  end

  def new
    @coupon = Coupon.new(
      coupon_type: "everyone",
      discount_type: "percentage",
      applicable_to: "courses",
      active: true
    )

    load_form_data
  end

  def create
    @coupon = Coupon.new(coupon_params)
    normalize_applicable_target

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
    attributes = coupon_params
    normalize_applicable_target(attributes)

    if @coupon.update(attributes)
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
    @test_series = TestSeries.order(:title)
    @ebooks = Ebook.order(:title)
    @students = User.student.order(:name)

  end

 def coupon_params
  params.require(:coupon).permit(
    :code,
    :course_id,
    :test_series_id,
    :ebook_id,
    :coupon_type,
    :student_id,
    :discount_type,
    :discount_value,
    :usage_limit,
    :expires_at,
    :active,
    :applicable_to
  )
end
def normalize_applicable_target(attributes = nil)
  target =
    if attributes
      attributes[:applicable_to]
    else
      @coupon.applicable_to
    end

  if attributes
    attributes[:course_id] = nil unless target == "courses"
    attributes[:test_series_id] = nil unless target == "test_series"
    attributes[:ebook_id] = nil unless target == "ebooks"
  else
    @coupon.course_id = nil unless target == "courses"
    @coupon.test_series_id = nil unless target == "test_series"
    @coupon.ebook_id = nil unless target == "ebooks"
  end
end

  def require_admin
    redirect_to root_path,
                alert: "Access Denied" unless current_user.admin?
  end
end
