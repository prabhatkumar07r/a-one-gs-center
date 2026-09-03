class Admin::TestSeriesQuestionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  before_action :set_test_series
  before_action :set_test

  before_action :set_question,
                only: %i[show edit update destroy]

  layout "admin"

  def index
    @questions =
      @test
        .test_series_questions
        .includes(:test_series_options)
        .order(position: :asc)
  end

  def show
    @options =
      @question
        .test_series_options
        .order(position: :asc)
  end

  def new
    @question =
      @test.test_series_questions.new(
        marks: 1,
        position: next_position
      )

    build_missing_options
  end

  def create
    @question =
      @test
        .test_series_questions
        .new(question_params)

    if @question.save
      redirect_to admin_test_series_test_path(
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

  def edit
    build_missing_options
  end

  def update
    if @question.update(question_params)
      redirect_to admin_test_series_test_path(
        @test_series,
        @test
      ),
      notice: "Question updated successfully."
    else
      build_missing_options

      render :edit,
             status: :unprocessable_entity
    end
  end

  def destroy
    @question.destroy

    redirect_to admin_test_series_test_path(
      @test_series,
      @test
    ),
    notice: "Question deleted successfully."
  end

  private

  def set_test_series
    @test_series =
      TestSeries.find(params[:test_series_id])
  end

  def set_test
    @test =
      @test_series
        .test_series_tests
        .find(params[:test_id])
  end

  def set_question
    @question =
      @test
        .test_series_questions
        .find(params[:id])
  end

  def next_position
    @test
      .test_series_questions
      .maximum(:position)
      .to_i + 1
  end

  def build_missing_options
    existing_count =
      @question.test_series_options.size

    missing_count =
      4 - existing_count

    missing_count.times do
      @question.test_series_options.build(
        position: existing_count + 1
      )

      existing_count += 1
    end
  end

  def question_params
    params
      .require(:test_series_question)
      .permit(
        :question_text,
        :question_text_hindi,
        :explanation,
        :explanation_hindi,
        :question_type,
        :marks,
        :position,

        test_series_options_attributes: [
          :id,
          :option_text,
          :option_text_hindi,
          :position,
          :is_correct,
          :_destroy
        ]
      )
  end

  def require_admin
    unless current_user.admin?
      redirect_to root_path,
                  alert: "Admin access required."
    end
  end
end