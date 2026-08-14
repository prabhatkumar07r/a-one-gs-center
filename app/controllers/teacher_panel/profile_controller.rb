class TeacherPanel::ProfileController < ApplicationController
  before_action :authenticate_user!
  before_action :require_teacher

  layout "teacher"

  def show
    @teacher = current_user.teacher
    @courses = @teacher.courses

    @students = User
                  .joins(:enrollments)
                  .where(enrollments: { course_id: @courses.ids })
                  .distinct

    @playlists = Playlist.where(course: @courses)
    @videos = Video.where(course: @courses)

    @resources = Resource
                   .joins(:playlist)
                   .where(playlists: { course_id: @courses.ids })

    @activities = []

    @courses.each do |course|
      @activities << {
        type: "course",
        title: "Created a new course",
        description: course.Course_name,
        created_at: course.created_at
      }
    end

    @playlists.each do |playlist|
      @activities << {
        type: "playlist",
        title: "Created a playlist",
        description: playlist.title,
        created_at: playlist.created_at
      }
    end

    @videos.each do |video|
      @activities << {
        type: "video",
        title: "Added a video",
        description: "A new video was added to your course.",
        created_at: video.created_at
      }
    end

    @resources.each do |resource|
      @activities << {
        type: "resource",
        title: "Added a resource",
        description: resource.title,
        created_at: resource.created_at
      }
    end

    @activities.sort_by! { |activity| activity[:created_at] }.reverse!
    @activities = @activities.first(20)
  end

  # ===========================
  # Edit Profile
  # ===========================
  def edit
    @teacher = current_user.teacher
  end

  # ===========================
  # Update Profile
  # ===========================
  def update
    @teacher = current_user.teacher

    if @teacher.update(teacher_params)
      redirect_to teacher_panel_profile_path,
                  notice: "Profile updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def teacher_params
    params.require(:teacher).permit(
      :name,
      :gmail,
      :mobile,
      :subject,
      :qualification,
      :designation,
      :experience,
      :bio,
      :facebook,
      :instagram,
      :linkedin,
      :photo
    )
  end
end