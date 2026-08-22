class EnrollmentsController < ApplicationController
  before_action :authenticate_user!

  # =========================================================
  # NEW ENROLLMENT
  # =========================================================

  def new
    @course = Course.find_by(id: params[:course_id])

    unless @course
      redirect_to root_path,
                  alert: "Course not found."
      return
    end

    existing_enrollment =
      current_user.enrollments.find_by(course_id: @course.id)

    if existing_enrollment

      case existing_enrollment.status

      when "Approved"
        redirect_to learning_course_path(@course),
                    notice: "You already have access to this course."
        return

      when "Pending"
        redirect_to payment_path(existing_enrollment),
                    alert: "Your enrollment is already pending."
        return

      else
        # Rejected / Cancelled / any other status
        # Allow the user to create a new enrollment
        existing_enrollment.destroy
      end
    end

    @enrollment = current_user.enrollments.new(
      course: @course,
      status: "Pending"
    )
  end


  # =========================================================
  # CREATE ENROLLMENT
  # =========================================================

  def create
    @course = Course.find_by(id: enrollment_params[:course_id])

    unless @course
      redirect_to root_path,
                  alert: "Course not found."
      return
    end

    existing_enrollment =
      current_user.enrollments.find_by(course_id: @course.id)

    if existing_enrollment

      case existing_enrollment.status

      when "Approved"
        redirect_to learning_course_path(@course),
                    alert: "You are already enrolled in this course."
        return

      when "Pending"
        redirect_to payment_path(existing_enrollment),
                    alert: "Your enrollment is already pending."
        return

      else
        # Rejected / Cancelled / other status
        existing_enrollment.destroy
      end
    end

    @enrollment = current_user.enrollments.new(
      course: @course,
      status: "Pending"
    )

    if @enrollment.save

      # =====================================================
      # FREE COURSE
      # =====================================================

      if @course.free?
        @enrollment.update!(status: "Approved")

        redirect_to learning_course_path(@course),
                    notice: "You have been enrolled in this free course."

        return
      end

      # =====================================================
      # PAID COURSE
      # =====================================================

      redirect_to payment_path(@enrollment)

    else

      render :new,
             status: :unprocessable_entity

    end
  end


  private

  # =========================================================
  # STRONG PARAMETERS
  # =========================================================

  def enrollment_params
    params.require(:enrollment).permit(:course_id)
  end
end