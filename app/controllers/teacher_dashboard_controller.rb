class TeacherDashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_teacher

  layout "teacher"

  def index
    @courses = Course.order(created_at: :desc)
    @courses      = Course.count
    @students     = Student.count
    @videos       = Video.count
    @playlists    = Playlist.count
    @resources    = Resource.count
    @enrollments  = Enrollment.count
    @notifications = Notification.count

    @recent_students = Student.order(created_at: :desc).limit(5)
    @recent_videos   = Video.order(created_at: :desc).limit(5)
    @recent_resources = Resource.order(created_at: :desc).limit(5)
  end

  private

  def require_teacher
    redirect_to root_path, alert: "Access Denied" unless current_user.teacher?
  end
end