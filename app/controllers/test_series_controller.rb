class TestSeriesController < ApplicationController
  before_action :authenticate_user!

  # ==================================================
  # TEST SERIES INDEX
  # ==================================================

  def index
    @test_series = TestSeries.active

    # ------------------------------------------
    # SEARCH
    # ------------------------------------------

    if params[:search].present?
      search = "%#{params[:search].strip}%"

      @test_series =
        @test_series.where(
          "title ILIKE :search OR language ILIKE :search OR exam_name ILIKE :search",
          search: search
        )
    end

    # ------------------------------------------
    # MODE FILTER
    # ------------------------------------------

    case params[:mode].to_s.downcase

    when "online"
      @test_series = @test_series.online

    when "offline"
      @test_series = @test_series.offline
    end

    # ------------------------------------------
    # LANGUAGE FILTER
    # ------------------------------------------

    if params[:language].present? &&
       params[:language].downcase != "all"

      @test_series =
        @test_series.where(
          "LOWER(language) = ?",
          params[:language].downcase
        )
    end

    # ------------------------------------------
    # ORDER
    # ------------------------------------------

    @test_series =
      @test_series.order(created_at: :desc)

    # ------------------------------------------
    # TOTAL COUNT
    # ------------------------------------------

    @total_test_series =
      TestSeries.active.count

    # ------------------------------------------
    # LANGUAGES
    # ------------------------------------------

    @languages =
      TestSeries.active
                 .where.not(language: [nil, ""])
                 .distinct
                 .order(:language)
                 .pluck(:language)
  end


  # ==================================================
  # TEST SERIES SHOW
  # ==================================================

  def show

    @test_series =
      TestSeries
        .active
        .find(params[:id])


    # ------------------------------------------
    # TESTS IN THIS SERIES
    # ------------------------------------------

    @quizzes =
      @test_series
        .test_series_tests
        .active
        .includes(
          test_series_questions: :test_series_options
        )
        .order(test_number: :asc)


    # ------------------------------------------
    # CURRENT USER PURCHASE
    # ------------------------------------------

    @purchase =
      current_user
        .test_series_purchases
        .find_by(
          test_series: @test_series,
          payment_status: "paid",
          status: "Active"
        )

  end

end