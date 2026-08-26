class Admin::EnrollmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_enrollment, only: [:show, :edit, :update, :destroy]
      layout "admin"


  # =========================================================
  # INDEX
  # =========================================================

  def index
    @enrollments = Enrollment.includes(:user, :course)

    # Search by student name or email
    if params[:search].present?
      search = "%#{params[:search]}%"

      @enrollments = @enrollments
        .joins(:user)
        .where(
          "users.name ILIKE :search OR users.email ILIKE :search",
          search: search
        )
    end

    # Statistics
    @total_enrollments = Enrollment.count
    @pending = Enrollment.where(status: "Pending").count
    @approved = Enrollment.where(status: "Approved").count

    # Order
    @enrollments = @enrollments.order(created_at: :desc)

    # Pagination
    @enrollments = @enrollments.page(params[:page]).per(10)
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
  # UPDATE
  # =========================================================

  def update
    if @enrollment.update(enrollment_params)

      redirect_to admin_enrollment_path(@enrollment),
                  notice: "Enrollment updated successfully."

    else

      render :edit,
             status: :unprocessable_entity

    end
  end


  # =========================================================
  # DESTROY
  # =========================================================

  def destroy
    @enrollment.destroy

    redirect_to admin_enrollments_path,
                notice: "Enrollment deleted successfully."
  end


  private


  # =========================================================
  # FIND ENROLLMENT
  # =========================================================

  def set_enrollment
    @enrollment = Enrollment.includes(:user, :course).find(params[:id])
  end


  # =========================================================
  # STRONG PARAMETERS
  # =========================================================

  def enrollment_params
    params.require(:enrollment).permit(
      :status,
      :course_id,
      :user_id
    )
  end
end