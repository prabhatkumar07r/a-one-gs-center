class SampleController < ApplicationController
  def homepage
  @events = Event.order(created_at: :desc)
  @notifications = Notification.where(status: "Active").order(created_at: :desc)
  @courses = Course.where(status: "Active")
  @teachers = Teacher.where(status: "Active")
  @galleries = Gallery.where(status: "Active").order(created_at: :desc)
  @achievements=Achievement.where(status: "Active")
end

def debug_env
  render plain: <<~TEXT
    Rails.env: #{Rails.env}
    GOOGLE_CLIENT_ID: #{ENV["GOOGLE_CLIENT_ID"].inspect}
    GOOGLE_CLIENT_SECRET: #{ENV["GOOGLE_CLIENT_SECRET"] ? "PRESENT" : "MISSING"}
  TEXT
end

end

  