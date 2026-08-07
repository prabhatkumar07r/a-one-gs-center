class EnrollmentsController < ApplicationController
  before_action :authenticate_user!, only: [:new, :create, :index, :edit, :update, :destroy]
  before_action :check_admin, only: [:index, :edit, :update, :destroy]
  before_action :set_enrollment, only: [:show, :edit, :update, :destroy]

  # ==========================
  # Admin
  # ==========================

  def index
    @enrollments = Enrollment.includes(:user, :course)
                             .order(created_at: :desc)

    if params[:search].present?
      @enrollments = @enrollments.joins(:user)
                                 .where("users.name LIKE ?", "%#{params[:search]}%")
    end

    @enrollments = @enrollments.page(params[:page]).per(10)

    @total_enrollments = Enrollment.count
    @pending   = Enrollment.where(status: "Pending").count
    @approved  = Enrollment.where(status: "Approved").count
    @cancelled = Enrollment.where(status: "Cancelled").count
  end

  # ==========================
  # Student
  # ==========================

  def new
    @course = Course.find(params[:course_id])
    @enrollment = Enrollment.new
  end

  def create
    @course = Course.find(enrollment_params[:course_id])

    existing_enrollment = Enrollment.find_by(
      user: current_user,
      course: @course
    )

    if existing_enrollment.present?
      redirect_to course_details_path(@course),
                  alert: "You are already enrolled in this course."
      return
    end

    @enrollment = current_user.enrollments.build(
      course: @course,
      status: "Pending"
    )

    if @enrollment.save
      redirect_to course_details_path(@course),
                  notice: "Enrollment request submitted successfully."
    else
      redirect_to course_details_path(@course),
                  alert: "Enrollment failed."
    end
  end

  def show
  end

  def edit
  end

  def update
    if @enrollment.update(enrollment_params)
      redirect_to enrollments_path, notice: "Enrollment updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @enrollment.destroy
    redirect_to enrollments_path, notice: "Enrollment deleted successfully."
  end

  private

  def set_enrollment
    @enrollment = Enrollment.find(params[:id])
  end

  def enrollment_params
    params.require(:enrollment).permit(:course_id, :status)
  end

  def check_admin
    unless current_user&.admin?
      redirect_to homepage_path, alert: "Access Denied!"
    end
  end
end