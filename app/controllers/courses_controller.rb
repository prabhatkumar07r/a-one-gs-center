class CoursesController < ApplicationController

  before_action :set_course, only: [:details, :enroll_free]

  def details
    @enrollment = if user_signed_in?
                    current_user.enrollments.find_by(course_id: @course.id)
                  end

    @videos = @course.videos
  end


  # =========================================================
  # ENROLL FREE COURSE
  # =========================================================

  def enroll_free

    unless user_signed_in?
      redirect_to new_user_session_path,
                  alert: "Please login to enroll in this course."
      return
    end

    # -------------------------------------------------------
    # Make sure course is actually FREE
    # -------------------------------------------------------

    unless @course.final_fee.to_d <= 0
      redirect_to course_details_path(@course),
                  alert: "This course is not free."
      return
    end


    # -------------------------------------------------------
    # Find existing enrollment
    # -------------------------------------------------------

    enrollment = current_user.enrollments.find_by(
      course_id: @course.id
    )


    # -------------------------------------------------------
    # Existing enrollment
    # -------------------------------------------------------

    if enrollment

      # Already approved
      if enrollment.status == "Approved"

        redirect_to learning_course_path(@course),
                    notice: "You are already enrolled in this course."

        return
      end


      # Pending enrollment
      # FREE COURSE → automatically approve
      if enrollment.status == "Pending"

        enrollment.update!(status: "Approved")

        redirect_to learning_course_path(@course),
                    notice: "You have successfully enrolled for free!"

        return
      end


      # Any other status
      enrollment.update!(status: "Approved")

      redirect_to learning_course_path(@course),
                  notice: "You have successfully enrolled in this course!"

      return

    end


    # -------------------------------------------------------
    # No enrollment exists
    # Create new approved enrollment
    # -------------------------------------------------------

    enrollment = current_user.enrollments.new(
      course: @course,
      status: "Approved"
    )


    if enrollment.save

      redirect_to learning_course_path(@course),
                  notice: "You have successfully enrolled for free!"

    else

      redirect_to course_details_path(@course),
                  alert: enrollment.errors.full_messages.to_sentence

    end

  end


  private


  def set_course
    @course = Course.find(params[:id])
  end

end