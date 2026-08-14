module TeacherPanel
  class CoursesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_teacher
    before_action :set_course, only: [:show]

    layout "teacher"

    def index
      @courses = current_user.teacher.courses
    end

    def show
      @playlists = @course.playlists
    end

    private

    def require_teacher
      unless current_user.teacher? || current_user.admin?
        redirect_to root_path, alert: "Access Denied"
      end
    end

    def set_course
      @course = current_user.teacher.courses.find(params[:id])
    end
  end
end