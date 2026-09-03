class TeacherPanel::QuestionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_teacher
  before_action :set_course
  before_action :set_quiz
  before_action :set_question,
                only: %i[show edit update destroy]

  def index
    @questions = @quiz.questions
                       .includes(:options)
                       .order(:position)
  end
  layout "teacher"
  def new
    @question = @quiz.questions.new

    4.times do |index|
      @question.options.build(
        position: index + 1,
        is_correct: false
      )
    end
  end

  def create
    @question = @quiz.questions.new(question_params)

    if @question.save
      redirect_to teacher_panel_course_quiz_path(
        @course,
        @quiz
      ),
      notice: "Question created successfully."
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  def show
    @options = @question.options.order(:position)
  end

  def edit
    missing = 4 - @question.options.size

    missing.times do |index|
      @question.options.build(
        position: @question.options.size + index + 1,
        is_correct: false
      )
    end
  end

  def update
    if @question.update(question_params)
      redirect_to teacher_panel_course_quiz_path(
        @course,
        @quiz
      ),
      notice: "Question updated successfully."
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  def destroy
    @question.destroy

    redirect_to teacher_panel_course_quiz_path(
      @course,
      @quiz
    ),
    notice: "Question deleted successfully."
  end

  private

  def set_course
    @course =
      current_user.teacher.courses.find(params[:course_id])
  end

  def set_quiz
    @quiz =
      @course.quizzes.find(params[:quiz_id])
  end

  def set_question
    @question =
      @quiz.questions.find(params[:id])
  end

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

  def require_teacher
    unless current_user.teacher.present?
      redirect_to root_path,
                  alert: "Teacher access required."
    end
  end
end