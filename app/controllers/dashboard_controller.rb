class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  layout "admin"

  def index
    # =========================
    # Statistics
    # =========================

    @students      = User.student.count
    @teachers      = User.teacher.count
    @courses       = Course.count
    @enrollments   = Enrollment.count
    @payments      = Payment.count
    @demos         = Demo.count
    @notifications = Notification.count
    @batches       = Batch.count
    @videos        = Video.count
    @playlists     = Playlist.count
    @resources     = Resource.count

    # =========================
    # Recent Data
    # =========================

    @recent_students =
      User.student.order(created_at: :desc).limit(5)

    @recent_payments =
      Payment.order(created_at: :desc).limit(5)

    @recent_notifications =
      Notification.order(created_at: :desc).limit(5)

    # =========================
    # Charts
    # =========================

    @student_chart =
      Student.group_by_month(:created_at).count

    @payment_chart =
      Payment.group_by_month(:created_at).sum(:amount)

    @course_chart =
      Enrollment
        .joins(:course)
        .group("courses.Course_name")
        .count
  end

  private

  def require_admin
    redirect_to root_path, alert: "Access Denied" unless current_user.admin?
  end
end