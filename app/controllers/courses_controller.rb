class CoursesController < ApplicationController

  before_action :set_course, only: [:details]

  def details
    @enrollment = if user_signed_in?
                    current_user.enrollments.find_by(course_id: @course.id)
                  end

    @videos = @course.videos
  end

  private

  def set_course
    @course = Course.find(params[:id])
  end

end