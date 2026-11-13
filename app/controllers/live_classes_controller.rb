class LiveClassesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_course
  before_action :set_live_class
  before_action :authorize_live_class!

  # ==========================================
  # PROTECTED LIVE CLASS PAGE
  # ==========================================

  def watch
    # @course and @live_class are loaded
    # by the before_action callbacks.
  end

  private

  # ==========================================
  # COURSE
  # ==========================================

  def set_course
    @course = Course.find(params[:course_id])
  end

  # ==========================================
  # LIVE CLASS
  # ==========================================

  def set_live_class
    @live_class = @course.live_classes.find(params[:id])
  end

  # ==========================================
  # AUTHORIZATION
  # ==========================================

  def authorize_live_class!
    # Admin always has access
    return if current_user.admin?

    # Free live classes are accessible
    return if @live_class.free?

    # Enrolled classes require an approved enrollment
    approved_enrollment =
      Enrollment.exists?(
        user_id: current_user.id,
        course_id: @course.id,
        status: "Approved"
      )

    return if approved_enrollment

    redirect_to learning_course_path(@course),
                alert: "You are not authorized to access this live class."
  end
end