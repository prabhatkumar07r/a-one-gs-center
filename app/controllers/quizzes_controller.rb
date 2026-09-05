class QuizzesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_course
  before_action :set_quiz, only: [:show, :start, :submit, :result]
  before_action :check_test_series_access, only: [:show, :start, :submit, :result]

  # ==================================================
  # QUIZ INDEX
  # ==================================================

  def index
    @course_quizzes = @course.quizzes
                             .where(test_series_id: nil)
                             .includes(:video, :questions)
                             .order(created_at: :desc)
  end

  # ==================================================
  # SHOW QUIZ
  # ==================================================

  def show
    @attempt = current_user.quiz_attempts.find_by(
      quiz: @quiz,
      status: "in_progress"
    )

    unless @attempt
      redirect_to course_quizzes_path(@course),
                  alert: "Please start the quiz first."
      return
    end

    @questions = @quiz.questions
                       .includes(:options)
                       .order(:position)
  end

  # ==================================================
  # START QUIZ
  # ==================================================

  def start
    existing_attempt = current_user.quiz_attempts.find_by(
      quiz: @quiz,
      status: "in_progress"
    )

    if existing_attempt
      redirect_to course_quiz_path(@course, @quiz)
      return
    end

    @attempt = current_user.quiz_attempts.create!(
      quiz: @quiz,
      status: "in_progress",
      score: 0,
      total_marks: @quiz.questions.sum(:marks).to_d,
      percentage: 0,
      started_at: Time.current
    )

    redirect_to course_quiz_path(@course, @quiz)
  end

  # ==================================================
  # SUBMIT QUIZ
  # ==================================================

  def submit
    attempt = current_user.quiz_attempts.find_by!(
      id: params[:attempt_id],
      quiz_id: @quiz.id
    )

    if %w[submitted passed failed].include?(attempt.status)
      redirect_to course_quiz_result_path(
        @course,
        @quiz,
        attempt
      ),
      alert: "This quiz has already been submitted."
      return
    end

    score = 0.to_d
    total_marks = @quiz.questions.sum(:marks).to_d

    ActiveRecord::Base.transaction do
      @quiz.questions.order(:position).each do |question|
        selected_option_id =
          params.dig(:answers, question.id.to_s)

        option =
          question.options.find_by(
            id: selected_option_id
          )

        is_correct =
          option.present? && option.is_correct?

        marks_obtained =
          is_correct ? question.marks.to_d : 0.to_d

        score += marks_obtained

        attempt.quiz_answers.create!(
          question: question,
          option: option,
          selected_text: option&.option_text,
          is_correct: is_correct,
          marks_obtained: marks_obtained
        )
      end

      percentage =
        if total_marks > 0
          ((score / total_marks) * 100).round(2)
        else
          0
        end

      final_status =
        if percentage >= @quiz.passing_percentage.to_d
          "passed"
        else
          "failed"
        end

      attempt.update!(
        score: score,
        total_marks: total_marks,
        percentage: percentage,
        status: final_status,
        submitted_at: Time.current
      )
    end

    redirect_to course_quiz_result_path(
      @course,
      @quiz,
      attempt
    ),
    notice: "Quiz submitted successfully."

  rescue ActiveRecord::RecordNotFound
    redirect_to course_quizzes_path(@course),
                alert: "Quiz attempt not found."

  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error e.message
    Rails.logger.error e.record.errors.full_messages

    redirect_to course_quiz_path(@course, @quiz),
                alert: "Unable to submit quiz: #{e.record.errors.full_messages.to_sentence}"
  end

  # ==================================================
  # QUIZ RESULT
  # ==================================================

  def result
    @attempt = current_user.quiz_attempts
                           .where(quiz: @quiz)
                           .find(params[:attempt_id])

    @answers = @attempt.quiz_answers
                       .includes(:question, :option)
                       .order("questions.position ASC")
  end

  private

  # ==================================================
  # SET COURSE
  # ==================================================

  def set_course
    @course = Course.find(params[:course_id])
  end

  # ==================================================
  # SET QUIZ
  # ==================================================

  def set_quiz
    quiz_id = params[:id].presence || params[:quiz_id].presence

    unless quiz_id
      redirect_to course_quizzes_path(@course),
                  alert: "Quiz ID is missing."
      return
    end

    @quiz = @course.quizzes.find(quiz_id)
  end

  # ==================================================
  # TEST SERIES ACCESS
  # ==================================================

  def check_test_series_access
    # Normal course quiz
    # No Test Series attached
    return unless @quiz.test_series.present?

    test_series = @quiz.test_series

    # ------------------------------------------
    # FREE TEST SERIES
    # ------------------------------------------

    if test_series.free?
      return
    end

    # ------------------------------------------
    # PAID TEST SERIES
    # ------------------------------------------

    purchased =
      current_user.test_series_purchases.exists?(
        test_series: test_series,
        payment_status: "paid",
        status: "Active"
      )

    # ------------------------------------------
    # ACCESS GRANTED
    # ------------------------------------------

    return if purchased

    # ------------------------------------------
    # ACCESS DENIED
    # ------------------------------------------

    redirect_to test_series_path(test_series),
                alert: "Please purchase this Test Series to access its tests."
  end
end