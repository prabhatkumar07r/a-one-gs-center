module TeacherPanel
  class CoursesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_teacher
    before_action :set_course, only: [:show]

    layout "teacher"

    def index
      if current_user.admin?
        @courses = Course.all
      else
        @courses = current_user.teacher.courses
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