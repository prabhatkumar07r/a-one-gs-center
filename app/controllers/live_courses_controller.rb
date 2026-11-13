class LiveCoursesController < ApplicationController
  before_action :authenticate_user!

  def index
    approved_course_ids =
      current_user.enrollments
                  .where(status: "Approved")
                  .pluck(:course_id)

    accessible_classes =
      LiveClass
        .includes(:course)
        .where(
          "access_type = ? OR course_id IN (?)",
          "free",
          approved_course_ids
        )
        .order(scheduled_at: :asc)
        .to_a

    # ==========================================
    # AUTOMATIC / MANUAL STATUS
    # ==========================================

    @live_now =
      accessible_classes
        .select(&:live?)
        .sort_by(&:scheduled_at)

    @upcoming_classes =
      accessible_classes
        .select(&:upcoming?)
        .sort_by(&:scheduled_at)

    @ended_classes =
      accessible_classes
        .select(&:ended?)
        .sort_by { |live_class|
          live_class.scheduled_at || Time.zone.at(0)
        }
        .reverse
  end
end