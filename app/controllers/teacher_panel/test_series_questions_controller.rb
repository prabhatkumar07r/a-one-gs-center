class TeacherPanel::TestSeriesQuestionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_teacher

  before_action :set_test_series
  before_action :set_test

  before_action :set_question,
                only: %i[show edit update destroy]

  layout "teacher"


  # ==================================================
  # INDEX
  # ==================================================

  def index
    @questions =
      @test
        .test_series_questions
        .includes(:test_series_options)
        .order(position: :asc)
  end


  # ==================================================
  # NEW
  # ==================================================

  def new
    @question =
      @test
        .test_series_questions
        .new(
          marks: 1,
          question_type: "multiple_choice"
        )

    build_default_options
  end


  # ==================================================
  # CREATE
  # ==================================================

  def create
    @question =
      @test
        .test_series_questions
        .new(question_params)

    # Automatically assign next question position.
    #
    # This prevents:
    # PG::UniqueViolation
    #
    # caused by duplicate:
    # (test_series_test_id, position)

    @question.position =
      @test
        .test_series_questions
        .maximum(:position)
        .to_i + 1


    if @question.save

      redirect_to teacher_panel_test_series_test_questions_path(
        @test_series,
        @test
      ),
      notice: "Question created successfully."

    else

      build_missing_options

      render :new,
             status: :unprocessable_entity

    end
  end


  # ==================================================
  # SHOW
  # ==================================================

  def show

    @options =
      @question
        .test_series_options
        .order(position: :asc)

  end


  # ==================================================
  # EDIT
  # ==================================================

  def edit

    build_missing_options

  end


  # ==================================================
  # UPDATE
  # ==================================================

  def update

    if @question.update(question_params)

      redirect_to teacher_panel_test_series_test_question_path(
        @test_series,
        @test,
        @question
      ),
      notice: "Question updated successfully."

    else

      build_missing_options

      render :edit,
             status: :unprocessable_entity

    end

  end


  # ==================================================
  # DESTROY
  # ==================================================

  def destroy

    @question.destroy

    redirect_to teacher_panel_test_series_test_questions_path(
      @test_series,
      @test
    ),
    notice: "Question deleted successfully."

  end


  private


  # ==================================================
  # SET TEST SERIES
  # ==================================================

  def set_test_series

    @test_series =
      TestSeries.find(params[:test_series_id])

  end


  # ==================================================
  # SET TEST
  # ==================================================

  def set_test

    @test =
      @test_series
        .test_series_tests
        .find(params[:test_id])

  end


  # ==================================================
  # SET QUESTION
  # ==================================================

  def set_question

    @question =
      @test
        .test_series_questions
        .find(params[:id])

  end


  # ==================================================
  # DEFAULT OPTIONS
  # ==================================================

  def build_default_options

    4.times do |i|

      @question.test_series_options.build(
        position: i + 1,
        is_correct: false
      )

    end

  end


  # ==================================================
  # MISSING OPTIONS
  # ==================================================

  def build_missing_options

    existing_count =
      @question
        .test_series_options
        .length

    missing_count =
      4 - existing_count

    return if missing_count <= 0


    missing_count.times do |i|

      @question.test_series_options.build(
        position: existing_count + i + 1,
        is_correct: false
      )

    end

  end


  # ==================================================
  # STRONG PARAMETERS
  # ==================================================

  def question_params

    params
      .require(:test_series_question)
      .permit(

        # ------------------------------
        # ENGLISH QUESTION
        # ------------------------------

        :question_text,

        # ------------------------------
        # HINDI QUESTION
        # ------------------------------

        :question_text_hindi,

        # ------------------------------
        # QUESTION SETTINGS
        # ------------------------------

        :question_type,
        :marks,
        :position,

        # ------------------------------
        # ENGLISH EXPLANATION
        # ------------------------------

        :explanation,

        # ------------------------------
        # HINDI EXPLANATION
        # ------------------------------

        :explanation_hindi,


        # ------------------------------
        # OPTIONS
        # ------------------------------

        test_series_options_attributes: [

          :id,

          # English option
          :option_text,

          # Hindi option
          :option_text_hindi,

          :position,

          :is_correct,

          :_destroy

        ]

      )

  end


  # ==================================================
  # TEACHER AUTHORIZATION
  # ==================================================

  def require_teacher

    return if current_user.teacher.present?

    redirect_to root_path,
                alert: "Teacher access required."

  end

end