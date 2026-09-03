class TeacherPanel::QuizzesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_teacher
  before_action :set_course
  before_action :set_quiz, only: %i[show edit update destroy]

  layout "teacher"

  # =========================================================
  # INDEX
  # =========================================================

  def index
    @course_level_quizzes =
      @course.quizzes
             .where(test_series_id: nil)
             .includes(:video, :questions)
             .order(created_at: :desc)

    @test_series =
      @course.test_series
             .includes(quizzes: [:questions])
             .order(created_at: :desc)
  end

  # =========================================================
  # NEW
  # =========================================================

  def new
    @quiz = @course.quizzes.new(
      time_limit: 30,
      passing_percentage: 40,
      status: "Active"
    )

    @videos = @course.videos.order(:position)

    @test_series =
      @course.test_series.order(created_at: :desc)
  end

  # =========================================================
  # CREATE
  # =========================================================

  def create
    @quiz = @course.quizzes.new(quiz_params)

    if @quiz.save
      redirect_to teacher_panel_course_quizzes_path(@course),
                  notice: "Quiz created successfully."
    else
      @videos = @course.videos.order(:position)

      @test_series =
        @course.test_series.order(created_at: :desc)

      render :new, status: :unprocessable_entity
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
    @videos = @course.videos.order(:position)

    @test_series =
      @course.test_series.order(created_at: :desc)
  end

  # =========================================================
  # UPDATE
  # =========================================================

  def update
    if @quiz.update(quiz_params)
      redirect_to teacher_panel_course_quizzes_path(@course),
                  notice: "Quiz updated successfully."
    else
      @videos = @course.videos.order(:position)

      @test_series =
        @course.test_series.order(created_at: :desc)

      render :edit, status: :unprocessable_entity
    end
  end

  # =========================================================
  # DESTROY
  # =========================================================

  def destroy
    @quiz.destroy

    redirect_to teacher_panel_course_quizzes_path(@course),
                notice: "Quiz deleted successfully."
  end

  private

  # =========================================================
  # COURSE
  # =========================================================

  def set_course
    @course =
      current_user.teacher.courses.find(params[:course_id])
  end

  # =========================================================
  # QUIZ
  # =========================================================

  def set_quiz
    @quiz =
      @course.quizzes.find(params[:id])
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
      :video_id,
      :test_series_id
    )
  end

  # =========================================================
  # TEACHER ACCESS
  # =========================================================

  def require_teacher
    unless current_user.teacher.present?
      redirect_to root_path,
                  alert: "Teacher access required."
    end
  end
end