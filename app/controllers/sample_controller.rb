class SampleController < ApplicationController
  def homepage
  @events = Event.order(created_at: :desc)
  @notifications = Notification.where(status: "Active").order(created_at: :desc)
  @courses = Course.where(status: "Active")
  @teachers = Teacher.where(status: "Active")
  @galleries = Gallery.where(status: "Active").order(created_at: :desc)
  @achievements=Achievement.where(status: "Active")
end

end

  