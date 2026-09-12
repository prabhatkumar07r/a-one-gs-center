class QuizzesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_course
  before_action :set_quiz, only: [:show, :start, :submit, :result]


  # ==================================================
  # QUIZ INDEX
  # ==================================================

  def index
    @course_quizzes =
  @course.quizzes
         .includes(:video, :questions)
         .order(created_at: :desc)
  end


  # ==================================================
  # SHOW QUIZ
  # ==================================================

  def show
    @attempt =
      current_user.quiz_attempts.find_by(
        quiz: @quiz,
        status: "in_progress"
      )

    unless @attempt
      redirect_to course_quizzes_path(@course),
                  alert: "Please start the quiz first."
      return
    end

    @questions =
      @quiz.questions
           .includes(:options)
           .order(:position)
  end


  # ==================================================
  # START QUIZ
  # ==================================================

  def start

    existing_attempt =
      current_user.quiz_attempts.find_by(
        quiz: @quiz,
        status: "in_progress"
      )

    if existing_attempt
      redirect_to course_quiz_path(
        @course,
        @quiz
      )
      return
    end

    @attempt =
      current_user.quiz_attempts.create!(
        quiz: @quiz,
        status: "in_progress",
        score: 0,
        total_marks:
          @quiz.questions.sum(:marks).to_d,
        percentage: 0,
        started_at: Time.current
      )

    redirect_to course_quiz_path(
      @course,
      @quiz
    )
  end


  # ==================================================
  # SUBMIT QUIZ
  # ==================================================

  def submit

    attempt =
      current_user.quiz_attempts.find_by!(
        id: params[:attempt_id],
        quiz_id: @quiz.id
      )

    # --------------------------------------------------
    # PREVENT RESUBMISSION
    # --------------------------------------------------

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

    total_marks =
      @quiz.questions
           .sum(:marks)
           .to_d

    answers =
      params.fetch(:answers, {})

    ActiveRecord::Base.transaction do

      # ------------------------------------------------
      # PROCESS QUESTIONS
      # ------------------------------------------------

      @quiz.questions
           .includes(:options)
           .order(:position)
           .each do |question|

        selected_option_id =
          answers[question.id.to_s]

        # Unanswered
        next if selected_option_id.blank?

        # Find option belonging to this question
        option =
          question.options.find_by(
            id: selected_option_id
          )

        # Invalid option
        next unless option

        # Check answer
        is_correct =
          option.is_correct?

        # Marks
        marks_obtained =
          if is_correct
            question.marks.to_d
          else
            0.to_d
          end

        score += marks_obtained

        # Save answer
        attempt.quiz_answers.create!(
          question: question,
          option: option,
          selected_text: option.option_text,
          is_correct: is_correct,
          marks_obtained: marks_obtained
        )
      end


      # ------------------------------------------------
      # PERCENTAGE
      # ------------------------------------------------

      percentage =
        if total_marks.positive?

          (
            (score / total_marks) * 100
          ).round(2)

        else

          0.to_d

        end


      # ------------------------------------------------
      # PASS / FAIL
      # ------------------------------------------------

      passing_percentage =
        @quiz.passing_percentage.to_d

      final_status =
        if percentage >= passing_percentage
          "passed"
        else
          "failed"
        end


      # ------------------------------------------------
      # COMPLETE ATTEMPT
      # ------------------------------------------------

      attempt.update!(
        score: score,
        total_marks: total_marks,
        percentage: percentage,
        status: final_status,
        submitted_at: Time.current
      )
    end


    # --------------------------------------------------
    # RESULT
    # --------------------------------------------------

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

    Rails.logger.error(
      "Quiz submission failed: " \
      "#{e.record.errors.full_messages.to_sentence}"
    )

    redirect_to course_quiz_path(
      @course,
      @quiz
    ),
    alert:
      "Unable to submit quiz: " \
      "#{e.record.errors.full_messages.to_sentence}"
  end


  # ==================================================
  # QUIZ RESULT
  # ==================================================

  def result

    @attempt =
      current_user.quiz_attempts
                  .where(quiz: @quiz)
                  .find(params[:attempt_id])


    # --------------------------------------------------
    # ANSWERS
    # --------------------------------------------------

    @answers =
      @attempt.quiz_answers
              .includes(:question, :option)
              .order("questions.position ASC")


    # --------------------------------------------------
    # LEADERBOARD
    # --------------------------------------------------

    @leaderboard =
      build_leaderboard


    # --------------------------------------------------
    # TOP 3
    # --------------------------------------------------

    @top_three =
      @leaderboard.first(3)


    # --------------------------------------------------
    # OTHER PARTICIPANTS
    # --------------------------------------------------

    @other_participants =
      @leaderboard.drop(3)
  end


  private


  # ==================================================
  # BUILD LEADERBOARD
  # ==================================================

  def build_leaderboard

    completed_attempts =
      QuizAttempt
        .where(quiz: @quiz)
        .where(
          status: %w[
            submitted
            passed
            failed
          ]
        )
        .includes(:user)


    # --------------------------------------------------
    # GROUP ATTEMPTS BY USER
    # --------------------------------------------------

    attempts_by_user =
      completed_attempts.group_by(&:user_id)


    # --------------------------------------------------
    # CREATE ONE ENTRY PER STUDENT
    # --------------------------------------------------

    leaderboard =
      attempts_by_user.filter_map do |user_id, attempts|

        user =
          attempts.first.user

        next unless user


        # ----------------------------------------------
        # BEST ATTEMPT
        # ----------------------------------------------

        best_attempt =
          attempts.max_by do |attempt|

            [
              attempt.percentage.to_d,
              attempt.score.to_d
            ]

          end

        next unless best_attempt


        # ----------------------------------------------
        # STUDENT NAME
        # ----------------------------------------------

        student_name =
          if user.respond_to?(:name) &&
             user.name.present?

            user.name

          elsif user.respond_to?(:full_name) &&
                user.full_name.present?

            user.full_name

          else

            user.email
                .to_s
                .split("@")
                .first
                .to_s
                .titleize

          end


        # ----------------------------------------------
        # DURATION
        # ----------------------------------------------

        duration =
          attempt_duration_seconds(
            best_attempt
          )


        {
          user_id: user_id,

          user: user,

          name: student_name,

          best_attempt: best_attempt,

          attempts: attempts.count,

          percentage:
            best_attempt.percentage.to_d,

          score:
            best_attempt.score.to_d,

          total_marks:
            best_attempt.total_marks.to_d,

          duration: duration
        }

      end


    # --------------------------------------------------
    # FINAL RANKING
    # --------------------------------------------------

    leaderboard =
      leaderboard.sort_by do |student|

        [
          # 1. Highest percentage
          -student[:percentage],

          # 2. Highest score
          -student[:score],

          # 3. Fewer attempts
          student[:attempts],

          # 4. Faster completion
          student[:duration]
        ]

      end


    # --------------------------------------------------
    # ASSIGN RANK
    # --------------------------------------------------

    leaderboard.each_with_index do |student, index|

      student[:rank] =
        index + 1

    end


    # --------------------------------------------------
    # TOP 10
    # --------------------------------------------------

    leaderboard.first(10)
  end


  # ==================================================
  # ATTEMPT DURATION
  # ==================================================

  def attempt_duration_seconds(attempt)

    return Float::INFINITY unless
      attempt.started_at.present? &&
      attempt.submitted_at.present?


    duration =
      attempt.submitted_at -
      attempt.started_at


    duration.to_i
  end


  # ==================================================
  # SET COURSE
  # ==================================================

  def set_course

    @course =
      Course.find(params[:course_id])

  end


  # ==================================================
  # SET QUIZ
  # ==================================================

  def set_quiz

    quiz_id =
      params[:id].presence ||
      params[:quiz_id].presence


    unless quiz_id

      redirect_to course_quizzes_path(@course),
                  alert: "Quiz ID is missing."

      return

    end


    @quiz =
      @course.quizzes.find(quiz_id)

  end


  # ==================================================
  # TEST SERIES ACCESS
  # ==================================================

 
end