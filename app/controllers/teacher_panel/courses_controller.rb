module TeacherPanel

  class CoursesController < ApplicationController

    before_action :authenticate_user!
    before_action :require_teacher
    before_action :set_teacher_course, only: [:show]


    layout "teacher"


    def index
        puts "===================="
  puts current_user.inspect
  puts current_user.teacher.inspect
  puts "===================="

      @courses = current_user.teacher.courses

    end


    def show

      @playlists = @course.playlists

    end


    private




    def require_teacher

      unless current_user.teacher? || current_user.admin?

        redirect_to root_path,
        alert: "Access Denied"

      end

    end


  end
  def set_course
  @course = Course.find(params[:course_id])
end

end