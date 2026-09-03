class Admin::TestSeriesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_test_series,
                only: %i[show edit update destroy]

  layout "admin"

  def index
    @test_series =
      TestSeries
        .includes(:test_series_tests)
        .order(created_at: :desc)
  end

  def show
    @tests =
      @test_series
        .test_series_tests
        .includes(:test_series_questions)
        .order(test_number: :asc)
  end

  def new
    @test_series = TestSeries.new(
      status: "Active",
      discount: 0
    )
  end

  def create
    @test_series = TestSeries.new(test_series_params)

    if @test_series.save
      redirect_to admin_test_series_path(@test_series),
                  notice: "Test Series created successfully."
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @test_series.update(test_series_params)
      redirect_to admin_test_series_path(@test_series),
                  notice: "Test Series updated successfully."
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  def destroy
    @test_series.destroy

    redirect_to admin_test_series_index_path,
                notice: "Test Series deleted successfully."
  end

  private

  def set_test_series
    @test_series = TestSeries.find(params[:id])
  end

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

  def require_admin
    unless current_user.admin?
      redirect_to root_path,
                  alert: "Admin access required."
    end
  end
end