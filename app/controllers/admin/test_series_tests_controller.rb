class Admin::TestSeriesTestsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  before_action :set_test_series

  before_action :set_test_series_test,
                only: %i[show edit update destroy]

  layout "admin"

  def index
    @test_series_tests =
      @test_series
        .test_series_tests
        .includes(:test_series_questions)
        .order(test_number: :asc)
  end

  def show
    @questions =
      @test_series_test
        .test_series_questions
        .includes(:test_series_options)
        .order(position: :asc)
  end

  def new
    @test_series_test =
      @test_series.test_series_tests.new(
        status: "Active",
        duration: 30
      )
  end

  def create
    @test_series_test =
      @test_series.test_series_tests.new(
        test_series_test_params
      )

    if @test_series_test.save
      redirect_to admin_test_series_test_path(
        @test_series,
        @test_series_test
      ),
      notice: "Test created successfully."
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @test_series_test.update(test_series_test_params)
      redirect_to admin_test_series_test_path(
        @test_series,
        @test_series_test
      ),
      notice: "Test updated successfully."
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  def destroy
    @test_series_test.destroy

    redirect_to admin_test_series_path(@test_series),
                notice: "Test deleted successfully."
  end

  private

  def set_test_series
    @test_series =
      TestSeries.find(params[:test_series_id])
  end

  def set_test_series_test
    @test_series_test =
      @test_series
        .test_series_tests
        .find(params[:id])
  end

  def test_series_test_params
    params.require(:test_series_test).permit(
      :title,
      :description,
      :test_number,
      :duration,
      :status
    )
  end

  def require_admin
    unless current_user.admin?
      redirect_to root_path,
                  alert: "Admin access required."
    end
  end
end