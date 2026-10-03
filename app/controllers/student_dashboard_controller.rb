class StudentDashboardController < ApplicationController
  before_action :authenticate_user!

  def index

    # =====================================================
    # COURSES
    # =====================================================

    @enrollments =
      current_user
        .enrollments
        .where(status: "Approved")
        .includes(course: :videos)
        .order(created_at: :desc)

    @courses =
      @enrollments.map(&:course)


    # =====================================================
    # LAST WATCHED VIDEO
    # =====================================================

    @last_progress =
      current_user
        .video_progresses
        .includes(video: :course)
        .order(updated_at: :desc)
        .first


    # =====================================================
    # COURSE PROGRESS
    # =====================================================

    @course_progress = {}

    @courses.each do |course|

      # Videos are already loaded by includes(course: :videos)
      total = course.videos.size

      completed =
        current_user
          .video_progresses
          .joins(:video)
          .where(
            videos: {
              course_id: course.id
            }
          )
          .where(completed: true)
          .count

      percent =
        total.zero? ?
          0 :
          ((completed.to_f / total) * 100).round

      @course_progress[course.id] = {
        total: total,
        completed: completed,
        percent: percent
      }

    end


    # =====================================================
    # TOTAL VIDEOS
    # Only videos from student's purchased courses
    # =====================================================

    @total_course_videos =
      @courses.sum do |course|
        course.videos.size
      end


    # =====================================================
    # RESOURCES
    # =====================================================

    @resources =
      Resource
        .joins(:playlist)
        .joins(
          "INNER JOIN enrollments ON enrollments.course_id = playlists.course_id"
        )
        .where(
          enrollments: {
            user_id: current_user.id
          }
        )
        .limit(5)


    # =====================================================
    # NOTIFICATIONS
    # =====================================================

    @notifications =
      Notification
        .order(created_at: :desc)
        .limit(5)


    # =====================================================
    # TEST SERIES PURCHASES
    # =====================================================

    @test_series_purchases =
      current_user
        .test_series_purchases
        .where(
          payment_status: "paid",
          status: "Active"
        )
        .includes(test_series: :test_series_tests)
        .order(created_at: :desc)


    # =====================================================
    # TEST PERFORMANCE
    # =====================================================

    @test_attempts =
      current_user
        .test_series_attempts
        .completed
        .includes(:test_series_test)
        .order(completed_at: :desc)
        .limit(10)


    # =====================================================
    # E-BOOK PURCHASES
    # =====================================================

    @ebook_purchases =
      current_user
        .ebook_purchases
        .paid
        .includes(:ebook)
        .order(created_at: :desc)

  end
end