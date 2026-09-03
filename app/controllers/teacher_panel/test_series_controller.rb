class TeacherPanel::TestSeriesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_teacher
  layout "teacher"

  before_action :set_test_series,
                only: %i[show edit update destroy]

  # ==================================================
  # LIST TEST SERIES
  # ==================================================

  def index
    @test_series = TestSeries
                    .order(created_at: :desc)
  end

  # ==================================================
  # SHOW TEST SERIES
  # ==================================================

  def show
    @tests = @test_series.test_series_tests
                         .includes(:test_series_questions)
                         .order(test_number: :asc)
  end

  # ==================================================
  # NEW
  # ==================================================

  def new
    @test_series = TestSeries.new(
      status: "Active",
      discount: 0
    )
  end

  # ==================================================
  # CREATE
  # ==================================================

  def create
    @test_series = TestSeries.new(test_series_params)

    if @test_series.save
      redirect_to teacher_panel_test_series_path(@test_series),
                  notice: "Test Series created successfully."
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
    if @test_series.update(test_series_params)
      redirect_to teacher_panel_test_series_path(@test_series),
                  notice: "Test Series updated successfully."
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  # ==================================================
  # DELETE
  # ==================================================

  def destroy
    @test_series.destroy

    redirect_to teacher_panel_test_series_index_path,
                notice: "Test Series deleted successfully."
  end

  private

  # ==================================================
  # FIND TEST SERIES
  # ==================================================

  def set_test_series
    @test_series = TestSeries.find(params[:id])
  end

  # ==================================================
  # STRONG PARAMETERS
  # ==================================================

  def test_series_params
    params.require(:test_series).permit(
      :title,
      :description,
      :exam_name,
      :mode,
      :language,
      :price,
      :original_price,
      :discount,
      :status,
      :registration_ended,
      :image
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