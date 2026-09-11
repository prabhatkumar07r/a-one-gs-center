class SampleController < ApplicationController

  def homepage

    # =========================================================
    # EVENTS
    # Latest 6 events + preload photos
    # =========================================================
    @events = Event
      .with_attached_photo
      .order(created_at: :desc)
      .limit(6)


    # =========================================================
    # NOTIFICATIONS
    # =========================================================
    @notifications = Notification
      .where(status: "Active")
      .order(created_at: :desc)


    # =========================================================
    # COURSES
    # Active courses + preload course images
    # =========================================================
    @courses = Course
      .where(status: "Active")
      .includes(image_attachment: :blob)


    # =========================================================
    # TEACHERS
    # Active teachers + preload teacher photos
    # =========================================================
    @teachers = Teacher
      .where(status: "Active")
      .includes(photo_attachment: :blob)


    # =========================================================
    # GALLERIES
    # Active galleries + preload all gallery photos
    # =========================================================
    @galleries = Gallery
     .where(status: "Active")
     .includes(photos_attachments: :blob)
     .order(created_at: :desc)


    # =========================================================
    # ACHIEVEMENTS
    # Active achievements + preload photo & video
    # =========================================================
    @achievements = Achievement
      .active
      .with_attached_photo
      .with_attached_video

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
