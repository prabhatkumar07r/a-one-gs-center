class Admin::TestSeriesOptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  before_action :set_test_series
  before_action :set_test
  before_action :set_question

  before_action :set_option,
                only: %i[show edit update destroy]

  layout "admin"

  def index
    @options =
      @question
        .test_series_options
        .order(position: :asc)
  end

  def show
  end

  def new
    @option =
      @question.test_series_options.new(
        position: next_position
      )
  end

  def create
    @option =
      @question
        .test_series_options
        .new(option_params)

    if @option.save
      redirect_to admin_test_series_test_question_path(
        @test_series,
        @test,
        @question
      ),
      notice: "Option created successfully."
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @option.update(option_params)
      redirect_to admin_test_series_test_question_path(
        @test_series,
        @test,
        @question
      ),
      notice: "Option updated successfully."
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  def destroy
    @option.destroy

    redirect_to admin_test_series_test_question_path(
      @test_series,
      @test,
      @question
    ),
    notice: "Option deleted successfully."
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
        .find(params[:question_id])
  end

  def set_option
    @option =
      @question
        .test_series_options
        .find(params[:id])
  end

  def next_position
    @question
      .test_series_options
      .maximum(:position)
      .to_i + 1
  end

  def option_params
    params
      .require(:test_series_option)
      .permit(
        :option_text,
        :option_text_hindi,
        :position,
        :is_correct
      )
  end

  def require_admin
    unless current_user.admin?
      redirect_to root_path,
                  alert: "Admin access required."
    end
  end
end