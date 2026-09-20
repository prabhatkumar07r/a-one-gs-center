class Admin::PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_payment, only: [:show]

  layout "admin"

  PER_PAGE = 20

  def index
    @payments =
      Payment
        .includes(
          enrollment: [
            :user,
            :course
          ]
        )
        .order(created_at: :desc)

    # =========================================================
    # SEARCH
    # =========================================================

    if params[:search].present?
      search = "%#{params[:search].strip.downcase}%"

      @payments =
        @payments
          .joins(
            enrollment: [
              :user,
              :course
            ]
          )
          .where(
            "LOWER(users.name) LIKE :search
             OR LOWER(users.email) LIKE :search
             OR LOWER(courses.Course_name) LIKE :search
             OR CAST(payments.id AS TEXT) LIKE :search
             OR LOWER(payments.razorpay_order_id) LIKE :search
             OR LOWER(payments.razorpay_payment_id) LIKE :search",
            search: search
          )
    end

    # =========================================================
    # STATUS FILTER
    # =========================================================

    if params[:status].present?
      @payments =
        @payments.where(
          status: params[:status]
        )
    end

    # =========================================================
    # COURSE FILTER
    # =========================================================

    if params[:course].present?
      @payments =
        @payments
          .joins(enrollment: :course)
          .where(
            courses: {
              Course_name: params[:course]
            }
          )
    end

    # =========================================================
    # FILTERED COUNT
    # =========================================================

    @filtered_payments_count =
      @payments.count

    # =========================================================
    # PAGINATION
    # =========================================================

    @page =
      params[:page].to_i

    @page = 1 if @page < 1

    @total_pages =
      (@filtered_payments_count.to_f / PER_PAGE).ceil

    @total_pages = 1 if @total_pages.zero?

    @page =
      @total_pages if @page > @total_pages
      @per_page = PER_PAGE

    @payments =
      @payments
        .offset(
          (@page - 1) * PER_PAGE
        )
        .limit(PER_PAGE)

    # =========================================================
    # PAYMENT STATISTICS
    # These remain global, not affected by filters
    # =========================================================

    @total_payments =
      Payment.count

    @successful_payments =
      Payment.where(
        status: "paid"
      ).count

    @pending_payments =
      Payment.where(
        status: "created"
      ).count

    @failed_payments =
      Payment
        .where(
          status: [
            "failed",
            "cancelled"
          ]
        )
        .count

    @total_revenue =
      Payment
        .where(
          status: "paid"
        )
        .sum(:amount)

    # =========================================================
    # COURSE LIST FOR FILTER
    # =========================================================

    @payment_courses =
      Course
        .where(
          id: Payment
            .joins(:enrollment)
            .select(
              "enrollments.course_id"
            )
        )
        .order(
          Course_name: :asc
        )
  end

  # =========================================================
  # SHOW
  # =========================================================

  def show
  end

  private

  # =========================================================
  # FIND PAYMENT
  # =========================================================

  def set_payment
    @payment =
      Payment
        .includes(
          enrollment: [
            :user,
            :course
          ]
        )
        .find(params[:id])
  end

  # =========================================================
  # ADMIN ACCESS
  # =========================================================

  def require_admin
    redirect_to root_path,
                alert: "Access Denied" unless current_user.admin?
  end
end