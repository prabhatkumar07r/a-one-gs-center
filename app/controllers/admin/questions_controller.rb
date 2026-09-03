class Admin::QuestionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  before_action :set_course
  before_action :set_quiz
  before_action :set_question, only: [:show, :edit, :update, :destroy]

  layout "admin"

  # ==================================================
  # INDEX
  # ==================================================

  def index
    @questions =
      @quiz.questions
           .includes(:options)
           .order(:position)
  end


  # ==================================================
  # SHOW
  # ==================================================

  def show
    @options = @question.options.order(:position)
  end


  # ==================================================
  # NEW
  # ==================================================

  def new
  @question = @quiz.questions.new

  4.times do
    @question.options.build
  end
end


  # ==================================================
  # CREATE
  # ==================================================

  def create
    @question = @quiz.questions.new(question_params)

    if @question.save

      redirect_to admin_course_quiz_path(
        @course,
        @quiz
      ),
      notice: "Question added successfully."

    else

      render :new,
             status: :unprocessable_entity

    end
  end


  # ==================================================
  # EDIT
  # ==================================================

  def edit
    @options =
      @question.options.order(:position)
  end


  # ==================================================
  # UPDATE
  # ==================================================

  def update

    if @question.update(question_params)

      redirect_to admin_course_quiz_path(
        @course,
        @quiz
      ),
      notice: "Question updated successfully."

    else

      render :edit,
             status: :unprocessable_entity

    end
  end


  # ==================================================
  # DESTROY
  # ==================================================

  def destroy

    @question.destroy

    redirect_to admin_course_quiz_path(
      @course,
      @quiz
    ),
    notice: "Question deleted successfully."

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
      @course.quizzes.find(params[:quiz_id])

  end


  # ==================================================
  # QUESTION
  # ==================================================

  def set_question

    @question =
      @quiz.questions.find(params[:id])

  end


  # ==================================================
  # PARAMETERS
  # ==================================================

  def question_params

    params.require(:question).permit(
      :question_text,
      :marks,
      :position,
      options_attributes: [
        :id,
        :option_text,
        :is_correct,
        :position,
        :_destroy
      ]
    )

  end


  # ==================================================
  # ADMIN
  # ==================================================

  def require_admin

    unless current_user.present? &&
           current_user.admin?

      redirect_to root_path,
                  alert: "Admin access required."

    end

  end

end