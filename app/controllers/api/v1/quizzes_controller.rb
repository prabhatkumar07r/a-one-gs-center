module Api
  module V1
    class QuizzesController < Api::ApplicationController

      def attempt
        quiz = Quiz.find(params[:id])

        unless quiz.status.to_s.casecmp("Active").zero?
          return render json: {
            success: false,
            error: "Quiz is not available."
          }, status: :not_found
        end

        enrollment =
          current_user.enrollments.find_by(
            course_id: quiz.course_id,
            status: "Approved"
          )

        unless enrollment
          return render json: {
            success: false,
            error: "You do not have access to this quiz."
          }, status: :forbidden
        end

        questions = quiz.questions.order(:position)
        total_marks = questions.sum(:marks)

        answers = params[:answers]

        unless answers.is_a?(Array) && answers.any?
          return render json: {
            success: false,
            error: "Answers must be provided as an array."
          }, status: :unprocessable_entity
        end

        attempt = QuizAttempt.create!(
          quiz: quiz,
          user: current_user,
          total_marks: total_marks,
          score: 0,
          percentage: 0,
          status: "in_progress",
          started_at: Time.current
        )

        score = 0

              ActiveRecord::Base.transaction do
          answers.each do |answer|
            question = quiz.questions.find(answer[:question_id])

            selected_option =
              question.options.find_by(
                id: answer[:selected_option_id]
              )

            unless selected_option
              raise ActiveRecord::RecordInvalid.new(
                QuizAnswer.new
              )
            end

            correct = selected_option.is_correct?

            marks_obtained =
              correct ? question.marks.to_d : 0

            score += marks_obtained

            QuizAnswer.create!(
              quiz_attempt: attempt,
              question: question,
              option: selected_option,
              marks_obtained: marks_obtained,
              selected_text: selected_option.option_text,
              is_correct: correct
            )
          end

          percentage =
            if total_marks.to_d.zero?
              0
            else
              (score.to_d / total_marks.to_d) * 100
            end

          status =
            if percentage >= quiz.passing_percentage.to_d
              "passed"
            else
              "failed"
            end

          attempt.update!(
            score: score,
            percentage: percentage,
            status: status,
            submitted_at: Time.current
          )
        end

        render json: {
          success: true,
          message: "Quiz submitted successfully.",
          data: {
            attempt_id: attempt.id,
            quiz_id: quiz.id,
            score: attempt.score,
            total_marks: attempt.total_marks,
            percentage: attempt.percentage,
            passing_percentage: quiz.passing_percentage,
            status: attempt.status,
            submitted_at: attempt.submitted_at
          }
        }, status: :ok

      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Quiz, question, or option not found."
        }, status: :not_found

      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "QUIZ SUBMIT VALIDATION ERROR: #{e.message}"
        Rails.logger.error "QUIZ SUBMIT ERRORS: #{e.record.errors.full_messages.inspect}"

        render json: {
          success: false,
          error: "Unable to submit quiz.",
          details: e.record.errors.full_messages
        }, status: :unprocessable_entity
      end


      def attempts
        quiz = Quiz.find(params[:id])

        unless quiz.status.to_s.casecmp("Active").zero?
          return render json: {
            success: false,
            error: "Quiz is not available."
          }, status: :not_found
        end

        quiz_attempts =
          current_user
            .quiz_attempts
            .where(quiz_id: quiz.id)
            .order(created_at: :desc)

        render json: {
          success: true,
          data: {
            quiz: {
              id: quiz.id,
              title: quiz.title
            },

            attempts: quiz_attempts.map do |attempt|
              {
                attempt_id: attempt.id,
                score: attempt.score,
                total_marks: attempt.total_marks,
                percentage: attempt.percentage,
                status: attempt.status,
                started_at: attempt.started_at,
                submitted_at: attempt.submitted_at
              }
            end
          }
        }, status: :ok

      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Quiz not found."
        }, status: :not_found
      end


     def attempt_result
  quiz = Quiz.find(params[:quiz_id])

  unless quiz.status.to_s.casecmp("Active").zero?
    return render json: {
      success: false,
      error: "Quiz is not available."
    }, status: :not_found
  end

  attempt =
    current_user
      .quiz_attempts
      .find_by(
        id: params[:attempt_id],
        quiz_id: quiz.id
      )

  unless attempt
    return render json: {
      success: false,
      error: "Quiz attempt not found."
    }, status: :not_found
  end

  answers =
    attempt
      .quiz_answers
      .includes(question: :options)
      .order(:id)

  render json: {
    success: true,

    data: {
      quiz: {
        id: quiz.id,
        title: quiz.title,
        passing_percentage: quiz.passing_percentage
      },

      attempt: {
        id: attempt.id,
        score: attempt.score,
        total_marks: attempt.total_marks,
        percentage: attempt.percentage,
        status: attempt.status,
        started_at: attempt.started_at,
        submitted_at: attempt.submitted_at
      },

      answers: answers.map do |answer|

        correct_option =
          answer.question.options.find(&:is_correct?)

        {
          question_id: answer.question_id,
          question_text: answer.question.question_text,

          selected_option_id: answer.option_id,
          selected_text: answer.selected_text,

          correct_option_id:
            correct_option&.id,

          correct_text:
            correct_option&.option_text,

          is_correct: answer.is_correct,
          marks_obtained: answer.marks_obtained,

          explanation:
            answer.question.explanation
        }
      end
    }
  }, status: :ok

rescue ActiveRecord::RecordNotFound
  render json: {
    success: false,
    error: "Quiz not found."
  }, status: :not_found
end

      def show
        quiz = Quiz.find(params[:id])
        enrollment =
  current_user.enrollments.find_by(
    course_id: quiz.course_id,
    status: "Approved"
  )

unless enrollment
  return render json: {
    success: false,
    error: "You do not have access to this quiz."
  }, status: :forbidden
end

        unless quiz.status.to_s.casecmp("Active").zero?
          return render json: {
            success: false,
            error: "Quiz is not available."
          }, status: :not_found
        end

        questions = quiz.questions.order(:position)

        render json: {
          success: true,
          data: {
            quiz: {
              id: quiz.id,
              title: quiz.title,
              description: quiz.description,
              time_limit: quiz.time_limit,
              passing_percentage: quiz.passing_percentage,
              course_id: quiz.course_id,
              video_id: quiz.video_id,
              test_series_id: quiz.test_series_id
            },

            questions: questions.map do |question|
              {
                id: question.id,
                question_text: question.question_text,
                question_type: question.question_type,
                marks: question.marks,
                position: question.position,

                options: question.options.order(:position).map do |option|
                  {
                    id: option.id,
                    option_text: option.option_text,
                    position: option.position
                  }
                end
              }
            end
          }
        }, status: :ok

      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Quiz not found."
        }, status: :not_found
      end

    end
  end
end