class TeacherPanel::StudentsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_teacher
  before_action :set_teacher_course

  layout "teacher"

  def index
    @students = @course.students
  end

  private

  def require_teacher
    unless current_user.teacher? || current_user.admin?
      redirect_to root_path, alert: "Access Denied"
    end
  end

  def set_teacher_course
    @course = current_user.teacher.courses.find(params[:course_id])
  end
end