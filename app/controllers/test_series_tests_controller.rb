class TestSeriesTestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_test_series
  before_action :set_test
  before_action :set_language
  before_action :set_attempt, only: [:show, :answer, :finish]

  # =========================================================
  # SHOW TEST / QUESTION
  # =========================================================

  def show
    @questions =
      @test
        .test_series_questions
        .includes(:test_series_options)
        .order(position: :asc)
        .to_a

    if @questions.empty?
      redirect_to test_series_path(@test_series),
                  alert: "This test does not have any questions yet."
      return
    end

    # -------------------------------------------------------
    # ANSWERED QUESTIONS
    # -------------------------------------------------------

    @answered_question_ids =
      @attempt
        .test_series_answers
        .pluck(:test_series_question_id)

    # -------------------------------------------------------
    # CURRENT QUESTION
    # -------------------------------------------------------

    question_number = params[:question].to_i

    if question_number > 0 &&
       question_number <= @questions.length

      @current_question_index = question_number - 1

    else

      unanswered_index =
        @questions.index do |question|
          !@answered_question_ids.include?(question.id)
        end

      @current_question_index =
        if unanswered_index
          unanswered_index
        else
          @questions.length - 1
        end

    end

    @question =
      @questions[@current_question_index]

    # -------------------------------------------------------
    # CURRENT ANSWER
    # -------------------------------------------------------

    @current_answer =
      @attempt
        .test_series_answers
        .find_by(
          test_series_question_id: @question.id
        )

    @selected_option_id =
      @current_answer&.test_series_option_id

    # -------------------------------------------------------
    # CORRECT OPTION
    # -------------------------------------------------------

    @correct_option =
      @question
        .test_series_options
        .find(&:is_correct?)

    # -------------------------------------------------------
    # PREVIOUS / NEXT
    # -------------------------------------------------------

    @previous_question =
      if @current_question_index > 0
        @questions[@current_question_index - 1]
      end

    @next_question =
      if @current_question_index < @questions.length - 1
        @questions[@current_question_index + 1]
      end

    # -------------------------------------------------------
    # COUNTS
    # -------------------------------------------------------

    @answered_count =
      @answered_question_ids.length

    @total_questions =
      @questions.length

    @current_number =
      @current_question_index + 1

    @ready_to_finish =
      @answered_count >= @total_questions

    # -------------------------------------------------------
    # ANSWER DISPLAY
    # -------------------------------------------------------

    @show_answer =
      params[:show_answer].to_s == "true"
  end


  # =========================================================
  # SAVE ANSWER
  # =========================================================

  def answer

    # -------------------------------------------------------
    # FIND QUESTION
    # -------------------------------------------------------

    question =
      @test
        .test_series_questions
        .find(params[:question_id])

    # -------------------------------------------------------
    # FIND OPTION BELONGING TO QUESTION
    # -------------------------------------------------------

    option =
      question
        .test_series_options
        .find_by(id: params[:option_id])

    unless option

      redirect_to test_series_test_series_test_path(
        @test_series,
        @test,
        question: question_number_for(question),
        language: @language
      ),
      alert: "Please select an option before continuing."

      return
    end

    # -------------------------------------------------------
    # CALCULATE RESULT
    # -------------------------------------------------------

    is_correct =
      option.is_correct?

    marks_obtained =
      if is_correct
        question.marks.to_f
      else
        0
      end

    # -------------------------------------------------------
    # CREATE / UPDATE ANSWER
    # -------------------------------------------------------

    answer =
      @attempt
        .test_series_answers
        .find_or_initialize_by(
          test_series_question: question
        )

    answer.test_series_option =
      option

    answer.is_correct =
      is_correct

    answer.marks_obtained =
      marks_obtained

    unless answer.save

      redirect_to test_series_test_series_test_path(
        @test_series,
        @test,
        question: question_number_for(question),
        language: @language
      ),
      alert: answer.errors.full_messages.to_sentence

      return
    end

    # =======================================================
    # DETERMINE CURRENT QUESTION NUMBER
    # =======================================================

    questions =
      @test
        .test_series_questions
        .order(position: :asc)
        .to_a

    current_index =
      questions.index do |q|
        q.id == question.id
      end

    # =======================================================
    # LAST QUESTION
    #
    # Save & Finish should actually finish the test.
    # =======================================================

    if current_index == questions.length - 1

      @attempt.update!(
        status: "Completed",
        completed_at: Time.current
      )

      redirect_to test_series_test_series_test_result_path(
        @test_series,
        @test,
        @attempt
      ),
      notice: "Test completed successfully."

      return
    end

    # =======================================================
    # NEXT QUESTION
    # =======================================================

    next_question_number =
      current_index + 2

    redirect_to test_series_test_series_test_path(
      @test_series,
      @test,
      question: next_question_number,
      language: @language
    )
  end


  # =========================================================
  # FINISH TEST
  # =========================================================

  def finish

    # -------------------------------------------------------
    # ALREADY COMPLETED
    # -------------------------------------------------------

    if @attempt.status == "Completed"

      redirect_to test_series_test_series_test_result_path(
        @test_series,
        @test,
        @attempt
      )

      return
    end

    # -------------------------------------------------------
    # CHECK WHETHER ALL QUESTIONS ARE ANSWERED
    # -------------------------------------------------------

    total_questions =
      @test
        .test_series_questions
        .count

    answered_questions =
      @attempt
        .test_series_answers
        .count

    if answered_questions < total_questions

      redirect_to test_series_test_series_test_path(
        @test_series,
        @test,
        question: 1,
        language: @language
      ),
      alert: "Please answer all questions before finishing the test."

      return
    end

    # -------------------------------------------------------
    # COMPLETE ATTEMPT
    # -------------------------------------------------------

    @attempt.update!(
      status: "Completed",
      completed_at: Time.current
    )

    redirect_to test_series_test_series_test_result_path(
      @test_series,
      @test,
      @attempt
    ),
    notice: "Test completed successfully."
  end


  private


  # =========================================================
  # SET TEST SERIES
  # =========================================================

  def set_test_series

    @test_series =
      TestSeries
        .active
        .find(params[:test_series_id])

  end


  # =========================================================
  # SET TEST
  # =========================================================

  def set_test

    @test =
      @test_series
        .test_series_tests
        .active
        .find(params[:id])

  end


  # =========================================================
  # SET LANGUAGE
  # =========================================================

  def set_language

    @language =
      params[:language].presence_in(%w[en hi]) || "en"

  end


  # =========================================================
  # SET / CREATE ATTEMPT
  # =========================================================

  def set_attempt

    @attempt =
      current_user
        .test_series_attempts
        .find_or_create_by!(
          test_series_test: @test
        ) do |attempt|

      attempt.status =
        "In Progress"

      attempt.started_at =
        Time.current

    end

  end


  # =========================================================
  # QUESTION NUMBER
  # =========================================================

  def question_number_for(question)

    questions =
      @test
        .test_series_questions
        .order(position: :asc)
        .to_a

    index =
      questions.index do |q|
        q.id == question.id
      end

    index ? index + 1 : 1

  end

end
