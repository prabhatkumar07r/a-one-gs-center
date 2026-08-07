class TeacherPanel::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_teacher

  before_action :set_teacher_course

  layout "teacher"

  def index
    @teacher = current_user.teacher

    if @teacher.present?
      @courses = @teacher.courses

      @students = User.joins(:enrollments)
                      .where(enrollments: { course_id: @courses.ids })
                      .distinct

      @videos = Video.where(course_id: @courses.ids)

      @playlists = Playlist.where(course_id: @courses.ids)

      @resources = Resource.joins(:playlist)
                           .where(playlists: { course_id: @courses.ids })
    else
      @courses = Course.none
      @students = User.none
      @videos = Video.none
      @playlists = Playlist.none
      @resources = Resource.none
    end

    @notifications = Notification.order(created_at: :desc).limit(5)
    @recent_courses = @courses.order(created_at: :desc).limit(5)
    @recent_students = @students.order(created_at: :desc).limit(5)
  end

  private

  def require_teacher
    redirect_to root_path, alert: "Access Denied" unless current_user.teacher?
  end
  def set_course
  @course = Course.find(params[:course_id])
end
end