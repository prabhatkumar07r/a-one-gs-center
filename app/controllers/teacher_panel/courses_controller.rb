module TeacherPanel
  class CoursesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_teacher
    before_action :set_course, only: [:show]

    layout "teacher"

    def index
      if current_user.admin?
        @courses = Course
                      .with_attached_image
                      .order(created_at: :desc)
      else
        @courses = current_user.teacher.courses
                          .with_attached_image
                          .order(created_at: :desc)
      end
    end

    def show
      @playlists = @course.playlists
    end

    private

    def set_course
      if current_user.admin?
        @course = Course.find(params[:id])
      else
        @course = current_user.teacher.courses.find(params[:id])
      end
    end
  end
end