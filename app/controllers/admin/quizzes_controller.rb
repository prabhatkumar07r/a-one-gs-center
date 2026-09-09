class Admin::QuizzesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  layout "admin"

  before_action :set_course

  before_action :set_quiz,
                only: %i[
                  show
                  edit
                  update
                  destroy
                ]

  # =========================================================
  # INDEX
  # =========================================================

  def index
    @quizzes =
      @course.quizzes
             .includes(:video, :questions)
             .order(created_at: :desc)
  end

  # =========================================================
  # NEW
  # =========================================================

  def new
    @quiz =
      @course.quizzes.new(
        time_limit: 30,
        passing_percentage: 40,
        status: "Active"
      )

    load_playlists
  end

  # =========================================================
  # CREATE
  # =========================================================

  def create
    @quiz =
      @course.quizzes.new(quiz_params)

    quiz_type =
      params[:quiz_type].to_s

    # ---------------------------------------------------------
    # COURSE LEVEL QUIZ
    # ---------------------------------------------------------

    if quiz_type == "course"

      @quiz.video_id = nil

    # ---------------------------------------------------------
    # VIDEO-WISE QUIZ
    # ---------------------------------------------------------

    elsif quiz_type == "video"

      video =
        find_selected_video

      unless video

        @quiz.errors.add(
          :video_id,
          "must be selected"
        )

        load_playlists

        return render(
          :new,
          status: :unprocessable_entity
        )
      end

      @quiz.video_id =
        video.id

    # ---------------------------------------------------------
    # INVALID TYPE
    # ---------------------------------------------------------

    else

      @quiz.errors.add(
        :base,
        "Please select a quiz type."
      )

      load_playlists

      return render(
        :new,
        status: :unprocessable_entity
      )

    end

    # ---------------------------------------------------------
    # SAVE
    # ---------------------------------------------------------

    if @quiz.save

      redirect_to(
        admin_course_quiz_path(
          @course,
          @quiz
        ),
        notice: "Quiz created successfully."
      )

    else

      load_playlists

      render(
        :new,
        status: :unprocessable_entity
      )

    end
  end

  # =========================================================
  # SHOW
  # =========================================================

  def show
    @questions =
      @quiz.questions
           .includes(:options)
           .order(:position)
  end

  # =========================================================
  # EDIT
  # =========================================================

  def edit
    load_playlists
  end

  # =========================================================
  # UPDATE
  # =========================================================

  def update
    quiz_type =
      params[:quiz_type].to_s

    attrs =
      quiz_params

    # ---------------------------------------------------------
    # COURSE LEVEL QUIZ
    # ---------------------------------------------------------

    if quiz_type == "course"

      attrs =
        attrs.merge(
          video_id: nil
        )

    # ---------------------------------------------------------
    # VIDEO-WISE QUIZ
    # ---------------------------------------------------------

    elsif quiz_type == "video"

      video =
        find_selected_video

      unless video

        @quiz.assign_attributes(attrs)

        @quiz.errors.add(
          :video_id,
          "must be selected"
        )

        load_playlists

        return render(
          :edit,
          status: :unprocessable_entity
        )
      end

      attrs =
        attrs.merge(
          video_id: video.id
        )

    # ---------------------------------------------------------
    # INVALID TYPE
    # ---------------------------------------------------------

    else

      @quiz.assign_attributes(attrs)

      @quiz.errors.add(
        :base,
        "Please select a quiz type."
      )

      load_playlists

      return render(
        :edit,
        status: :unprocessable_entity
      )

    end

    # ---------------------------------------------------------
    # UPDATE
    # ---------------------------------------------------------

    if @quiz.update(attrs)

      redirect_to(
        admin_course_quiz_path(
          @course,
          @quiz
        ),
        notice: "Quiz updated successfully."
      )

    else

      load_playlists

      render(
        :edit,
        status: :unprocessable_entity
      )

    end
  end

  # =========================================================
  # DESTROY
  # =========================================================

  def destroy
    @quiz.destroy

    redirect_to(
      admin_course_quizzes_path(
        @course
      ),
      notice: "Quiz deleted successfully."
    )
  end

  private

  # =========================================================
  # SET COURSE
  # =========================================================

  def set_course
    @course =
      Course.find(
        params[:course_id]
      )
  end

  # =========================================================
  # SET QUIZ
  # =========================================================

  def set_quiz
    @quiz =
      @course.quizzes.find(
        params[:id]
      )
  end

  # =========================================================
  # LOAD PLAYLISTS
  # =========================================================

  def load_playlists
    @playlists =
      @course.playlists
             .includes(:videos)
             .order(:position, :id)
  end

  # =========================================================
  # FIND SELECTED VIDEO
  # =========================================================
  #
  # The playlist dropdown is used to filter the videos.
  #
  # Quiz stores ONLY video_id.
  #
  # Course
  #   ↓
  # Playlist
  #   ↓
  # Video
  #   ↓
  # Quiz.video_id
  #
  # =========================================================

  def find_selected_video
    video_id =
      quiz_params[:video_id].presence

    return nil if video_id.blank?

    @course.videos.find_by(
      id: video_id
    )
  end

  # =========================================================
  # STRONG PARAMETERS
  # =========================================================

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

  # =========================================================
  # ADMIN AUTHORIZATION
  # =========================================================

  def require_admin
    unless current_user.present? &&
           current_user.admin?

      redirect_to(
        root_path,
        alert: "Admin access required."
      )

    end
  end
end