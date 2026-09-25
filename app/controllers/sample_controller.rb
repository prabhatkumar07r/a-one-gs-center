class SampleController < ApplicationController

  def homepage

    @events = Event
      .preload(photo_attachment: :blob)
      .order(created_at: :desc)
      .limit(6)

    @notifications = Notification
      .where(status: "Active")
      .order(created_at: :desc)
      .limit(10)

    @courses = Course
      .where(status: "Active")
      .preload(image_attachment: :blob)
      .order(created_at: :desc)
      .limit(8)

    @teachers = Teacher
      .where(status: "Active")
      .preload(photo_attachment: :blob)
      .order(created_at: :desc)
      .limit(6)

    @galleries = Gallery
      .where(status: "Active")
      .preload(photos_attachments: :blob)
      .order(created_at: :desc)
      .limit(8)

    @achievements = Achievement
      .active
      .preload(
        { photo_attachment: :blob },
        { video_attachment: :blob }
      )
      .order(created_at: :desc)
      .limit(6)

    @testimonials = Testimonial
      .active
      .preload(
        { student_photo_attachment: :blob },
        { video_attachment: :blob }
      )
      .ordered
      .limit(6)

  end

  def debug_env
    render plain: <<~TEXT
      Rails.env: #{Rails.env}
      GOOGLE_CLIENT_ID: #{ENV["GOOGLE_CLIENT_ID"].inspect}
      GOOGLE_CLIENT_SECRET: #{ENV["GOOGLE_CLIENT_SECRET"] ? "PRESENT" : "MISSING"}
    TEXT
  end

  def cloudinary_check
    render plain: {
      service: Rails.application.config.active_storage.service,
      cloud_name: ENV["CLOUDINARY_CLOUD_NAME"],
      api_key_present: ENV["CLOUDINARY_API_KEY"].present?,
      api_secret_present: ENV["CLOUDINARY_API_SECRET"].present?
    }.inspect
  end

  def blob_check
    teacher = Teacher.first

    if teacher&.photo&.attached?
      render plain: {
        teacher: teacher.name,
        service_name: teacher.photo.blob.service_name,
        filename: teacher.photo.filename.to_s
      }.inspect
    else
      render plain: "No photo attached"
    end
  end

end