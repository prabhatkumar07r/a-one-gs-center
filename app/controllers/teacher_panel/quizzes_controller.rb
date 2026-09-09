class TeacherPanel::QuizzesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_teacher
  before_action :set_course
  before_action :set_quiz, only: %i[show edit update destroy]

  layout "teacher"

 def index
  @course_level_quizzes =
    @course.quizzes
           .course_wise
           .includes(:questions)
           .order(created_at: :desc)

  @video_quizzes =
    @course.quizzes
           .video_wise
           .includes(:video, :questions)
           .order(created_at: :desc)
end

  def new
    @quiz = @course.quizzes.new(
      time_limit: 30,
      passing_percentage: 40,
      status: "Active"
    )

    load_form_data
  end

  def create
    @quiz = @course.quizzes.new(quiz_params)

    case params[:quiz_type].to_s

    when "course"
      @quiz.video_id = nil

    when "video"
      video = find_selected_video

      unless video
        @quiz.errors.add(:video_id, "must be selected")
        load_form_data
        return render :new, status: :unprocessable_entity
      end

      @quiz.video_id = video.id

    else
      @quiz.errors.add(:base, "Please select a quiz type.")
      load_form_data
      return render :new, status: :unprocessable_entity
    end

    if @quiz.save
      redirect_to teacher_panel_course_quizzes_path(@course),
                  notice: "Quiz created successfully."
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @questions = @quiz.questions
                       .includes(:options)
                       .order(:position)
  end

  def edit
    load_form_data
  end

  def update
    attrs = quiz_params

    case params[:quiz_type].to_s

    when "course"
      attrs = attrs.merge(video_id: nil)

    when "video"
      video = find_selected_video

      unless video
        @quiz.assign_attributes(attrs)
        @quiz.errors.add(:video_id, "must be selected")
        load_form_data
        return render :edit, status: :unprocessable_entity
      end

      attrs = attrs.merge(video_id: video.id)

    else
      @quiz.assign_attributes(attrs)
      @quiz.errors.add(:base, "Please select a quiz type.")
      load_form_data
      return render :edit, status: :unprocessable_entity
    end

    if @quiz.update(attrs)
      redirect_to teacher_panel_course_quizzes_path(@course),
                  notice: "Quiz updated successfully."
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @quiz.destroy

    redirect_to teacher_panel_course_quizzes_path(@course),
                notice: "Quiz deleted successfully."
  end

  private

  def set_course
    @course = current_user.teacher.courses.find(params[:course_id])
  end

  def set_quiz
    @quiz = @course.quizzes.find(params[:id])
  end

  def load_form_data
    @playlists = @course.playlists
                        .includes(:videos)
                        .order(:position, :id)

    @videos = @course.videos
                     .includes(:playlist)
                     .order(:position, :id)
  end

  def find_selected_video
    video_id = quiz_params[:video_id].presence
    return nil if video_id.blank?

    video = @course.videos.find_by(id: video_id)
    return nil unless video

    playlist_id = params[:quiz_playlist_id].presence

    if playlist_id.present?
      return nil unless video.playlist_id.to_s == playlist_id.to_s
    end

    video
  end

  def quiz_params
    params.require(:quiz).permit(
      :title,
      :description,
      :time_limit,
      :passing_percentage,
      :status,
      :video_id
    )
  end

  def require_teacher
    redirect_to root_path,
                alert: "Teacher access required." unless current_user.teacher?
  end
end