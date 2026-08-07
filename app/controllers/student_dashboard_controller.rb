class StudentDashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @enrollments = current_user.enrollments
                               .where(status: "Approved")
                               .includes(course: :videos)

    @courses = @enrollments.map(&:course)

    @last_progress = current_user.video_progresses
                                 .includes(video: :course)
                                 .order(updated_at: :desc)
                                 .first

    @course_progress = {}

    @courses.each do |course|
      total = course.videos.count

      completed = current_user.video_progresses
                              .joins(:video)
                              .where(videos: { course_id: course.id })
                              .where(completed: true)
                              .count

      percent = total.zero? ? 0 : ((completed.to_f / total) * 100).round

      @course_progress[course.id] = {
        total: total,
        completed: completed,
        percent: percent
      }
    end

    @resources = Resource.joins(:playlist)
                         .joins("INNER JOIN enrollments ON enrollments.course_id = playlists.course_id")
                         .where(enrollments: { user_id: current_user.id })
                         .limit(5)

    @notifications = Notification.order(created_at: :desc).limit(5)
  end
end