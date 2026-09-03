class TeacherPanel::TestSeriesTestsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_teacher
  before_action :set_test_series
  before_action :set_test_series_test,
                only: %i[show edit update destroy]

  layout "teacher"

  # ==================================================
  # INDEX
  # ==================================================

  def index
    @test_series_tests =
      @test_series
        .test_series_tests
        .includes(:test_series_questions)
        .order(test_number: :asc)
  end

  # ==================================================
  # SHOW
  # ==================================================

  def show
    @questions =
      @test_series_test
        .test_series_questions
        .includes(:test_series_options)
        .order(position: :asc)
  end

  # ==================================================
  # NEW
  # ==================================================

  def new
    @test_series_test =
      @test_series.test_series_tests.new(
        status: "Active",
        duration: 30
      )
  end

  # ==================================================
  # CREATE
  # ==================================================

  def create
    @test_series_test =
      @test_series.test_series_tests.new(
        test_series_test_params
      )

    if @test_series_test.save
      redirect_to teacher_panel_test_series_test_path(
        @test_series,
        @test_series_test
      ),
      notice: "Test created successfully."
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  # ==================================================
  # EDIT
  # ==================================================

  def edit
  end

  # ==================================================
  # UPDATE
  # ==================================================

  def update
    if @test_series_test.update(test_series_test_params)
      redirect_to teacher_panel_test_series_test_path(
        @test_series,
        @test_series_test
      ),
      notice: "Test updated successfully."
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  # ==================================================
  # DESTROY
  # ==================================================

  def destroy
    @test_series_test.destroy

    redirect_to teacher_panel_test_series_path(@test_series),
                notice: "Test deleted successfully."
  end

  private

  # ==================================================
  # FIND TEST SERIES
  # ==================================================

  def set_test_series
    @test_series =
      TestSeries.find(params[:test_series_id])
  end

  # ==================================================
  # FIND TEST
  # ==================================================

  def set_test_series_test
    @test_series_test =
      @test_series
        .test_series_tests
        .find(params[:id])
  end

  # ==================================================
  # STRONG PARAMETERS
  # ==================================================

  def test_series_test_params
    params.require(:test_series_test).permit(
      :title,
      :description,
      :test_number,
      :duration,
      :status
    )
  end

  # ==================================================
  # TEACHER ACCESS
  # ==================================================

  def require_teacher
    unless current_user.teacher.present?
      redirect_to root_path,
                  alert: "Teacher access required."
    end
  end
end