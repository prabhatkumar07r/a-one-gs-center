class TeacherDashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_teacher

  layout "teacher"

  def index
  teacher = current_user.teacher

  @courses = teacher.courses.order(created_at: :desc)

  @courses_count = @courses.count
  @students      = Enrollment.where(course: @courses).count
  @videos        = Video.joins(:course).where(course: @courses).count
  @playlists     = Playlist.where(course: @courses).count
  @resources     = Resource.joins(:course).where(course: @courses).count

  @recent_videos = Video.joins(:course)
                        .where(course: @courses)
                        .order(created_at: :desc)
                        .limit(5)
end

  private

  def require_teacher
    redirect_to root_path, alert: "Access Denied" unless current_user.teacher?
  end
end