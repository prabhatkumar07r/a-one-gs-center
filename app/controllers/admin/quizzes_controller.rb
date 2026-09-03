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


  # ==================================================
  # INDEX
  # ==================================================

  def index

    @quizzes =
      @course.quizzes
             .includes(:video, :questions)
             .order(created_at: :desc)

  end


  # ==================================================
  # NEW
  # ==================================================

  def new

    @quiz =
      @course.quizzes.new(
        time_limit: 30,
        passing_percentage: 40,
        status: "Active"
      )

    # DO NOT USE @quiz.questions HERE

  end


  # ==================================================
  # CREATE
  # ==================================================

  def create

    @quiz =
      @course.quizzes.new(quiz_params)

    if @quiz.save

      redirect_to admin_course_quiz_path(
        @course,
        @quiz
      ),
      notice: "Quiz created successfully."

    else

      render :new,
             status: :unprocessable_entity

    end

  end


  # ==================================================
  # SHOW
  # ==================================================

  def show

    @questions =
      @quiz.questions
           .includes(:options)
           .order(:position)

  end


  # ==================================================
  # EDIT
  # ==================================================

  def edit

    @videos =
      @course.videos.order(:position)

  end


  # ==================================================
  # UPDATE
  # ==================================================

  def update

    if @quiz.update(quiz_params)

      redirect_to admin_course_quiz_path(
        @course,
        @quiz
      ),
      notice: "Quiz updated successfully."

    else

      @videos =
        @course.videos.order(:position)

      render :edit,
             status: :unprocessable_entity

    end

  end


  # ==================================================
  # DESTROY
  # ==================================================

  def destroy

    @quiz.destroy

    redirect_to admin_course_quizzes_path(
      @course
    ),
    notice: "Quiz deleted successfully."

  end


  private


  # ==================================================
  # COURSE
  # ==================================================

  def set_course

    @course =
      Course.find(params[:course_id])

  end


  # ==================================================
  # QUIZ
  # ==================================================

  def set_quiz

    @quiz =
      @course.quizzes.find(params[:id])

  end


  # ==================================================
  # PARAMETERS
  # ==================================================

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


  # ==================================================
  # ADMIN AUTHORIZATION
  # ==================================================

  def require_admin

    unless current_user.present? &&
           current_user.admin?

      redirect_to root_path,
                  alert: "Admin access required."

    end

  end

end