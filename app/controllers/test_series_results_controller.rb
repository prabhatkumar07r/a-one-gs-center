class TestSeriesResultsController < ApplicationController

  before_action :authenticate_user!
  before_action :set_test_series
  before_action :set_test
  before_action :set_attempt


  # ==================================================
  # SHOW RESULT
  # ==================================================

  def show

    @questions =
      @test
        .test_series_questions
        .includes(:test_series_options)
        .order(position: :asc)


    @answers =
      @attempt
        .test_series_answers
        .includes(
          :test_series_question,
          :test_series_option
        )


    @answers_by_question =
      @answers.index_by(&:test_series_question_id)


    @correct_answers =
      @answers.count(&:is_correct?)


    @wrong_answers =
      @answers.count { |answer| !answer.is_correct? }


    @answered_questions =
      @answers.count


    @unanswered_questions =
      @questions.count - @answered_questions

  end


  private


  # ==================================================
  # TEST SERIES
  # ==================================================

  def set_test_series

    @test_series =
      TestSeries
        .active
        .find(params[:test_series_id])

  end


  # ==================================================
  # TEST
  # ==================================================

  def set_test

    @test =
      @test_series
        .test_series_tests
        .active
        .find(params[:test_series_test_id])

  end


  # ==================================================
  # ATTEMPT
  # ==================================================

  def set_attempt

    @attempt =
      current_user
        .test_series_attempts
        .find(params[:id])


    unless @attempt.test_series_test_id == @test.id

      redirect_to test_series_path(@test_series),
                  alert: "Invalid test result."

      return

    end

  end

end