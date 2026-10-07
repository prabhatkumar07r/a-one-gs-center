module Api
  module V1
    class TestSeriesTestsController < Api::ApplicationController
      before_action :set_test_series
      before_action :set_test
      before_action :check_access

      # GET
      # /api/v1/test_series/:test_series_id/tests/:id
      def show
        questions =
          @test
            .test_series_questions
            .includes(:test_series_options)
            .order(position: :asc)

        render json: {
          success: true,
          data: {
            test: test_json(@test),
            questions: questions.map do |question|
              question_json(question)
            end
          }
        }, status: :ok
      end

      # POST
      # /api/v1/test_series/:test_series_id/tests/:id/start
      def start
        attempt =
          current_user
            .test_series_attempts
            .where(test_series_test: @test)
            .in_progress
            .order(created_at: :desc)
            .first

        created = false

        unless attempt
          attempt =
            current_user
              .test_series_attempts
              .create!(
                test_series_test: @test,
                status: "In Progress",
                started_at: Time.current
              )

          created = true
        end

        render json: {
          success: true,
          message: created ? "Test started successfully." : "Test resumed successfully.",
          data: {
            attempt: attempt_json(attempt)
          }
        }, status: :ok
      end

      # POST
      # /api/v1/test_series/:test_series_id/tests/:id/answer
      def answer
        attempt = current_attempt

        unless attempt
          return render json: {
            success: false,
            error: "No active attempt found."
          }, status: :not_found
        end

        if exam_time_expired?(attempt)
          complete_attempt!(attempt)

          return render json: {
            success: false,
            error: "Time is over. Test has been submitted.",
            data: {
              attempt_id: attempt.id
            }
          }, status: :unprocessable_entity
        end

        question =
          @test
            .test_series_questions
            .find(params[:question_id])

        option =
          question
            .test_series_options
            .find_by(id: params[:option_id])

        unless option
          return render json: {
            success: false,
            error: "Selected option not found."
          }, status: :unprocessable_entity
        end

        is_correct = option.is_correct?
        marks_obtained = is_correct ? question.marks.to_f : 0

        answer =
          attempt
            .test_series_answers
            .find_or_initialize_by(
              test_series_question: question
            )

        answer.test_series_option = option
        answer.is_correct = is_correct
        answer.marks_obtained = marks_obtained
        answer.save!

        render json: {
          success: true,
          message: "Answer saved successfully.",
          data: {
            question_id: question.id,
            selected_option_id: option.id,
            is_correct: is_correct,
            marks_obtained: marks_obtained,
            answered_count: attempt.test_series_answers.count,
            total_questions: @test.test_series_questions.count
          }
        }, status: :ok

      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Question or option not found."
        }, status: :not_found

      rescue ActiveRecord::RecordInvalid
        render json: {
          success: false,
          error: "Unable to save answer."
        }, status: :unprocessable_entity
      end

      # POST
      # /api/v1/test_series/:test_series_id/tests/:id/bookmark
      def bookmark
        attempt = current_attempt

        unless attempt
          return render json: {
            success: false,
            error: "No active attempt found."
          }, status: :not_found
        end

        if exam_time_expired?(attempt)
          complete_attempt!(attempt)

          return render json: {
            success: false,
            error: "Time is over. Test has been submitted."
          }, status: :unprocessable_entity
        end

        question =
          @test
            .test_series_questions
            .find(params[:question_id])

        attempt_question =
          attempt
            .test_series_attempt_questions
            .find_or_initialize_by(
              test_series_question: question
            )

        attempt_question.bookmarked =
          !attempt_question.bookmarked?

        attempt_question.save!

        render json: {
          success: true,
          message: "Bookmark updated.",
          data: {
            question_id: question.id,
            bookmarked: attempt_question.bookmarked?
          }
        }, status: :ok

      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Question not found."
        }, status: :not_found
      end

      # POST
      # /api/v1/test_series/:test_series_id/tests/:id/finish
      def finish
        attempt = current_attempt

        unless attempt
          return render json: {
            success: false,
            error: "No active attempt found."
          }, status: :not_found
        end

        if attempt.completed?
          return render_finished_result(attempt)
        end

        complete_attempt!(attempt)

        render_finished_result(attempt)

      rescue ActiveRecord::RecordInvalid
        render json: {
          success: false,
          error: "Unable to finish test."
        }, status: :unprocessable_entity
      end

      # GET
      # /api/v1/test_series/:test_series_id/tests/:id/result
      def result
        attempt =
          current_user
            .test_series_attempts
            .find_by(test_series_test: @test)

        unless attempt
          return render json: {
            success: false,
            error: "No attempt found for this test."
          }, status: :not_found
        end

        render_result(attempt)
      end

      private

      def set_test_series
        @test_series =
          TestSeries
            .active
            .find(params[:test_series_id])
      end

      def set_test
        @test =
          @test_series
            .test_series_tests
            .active
            .find(params[:id])
      end

      def check_access
        return if @test_series.free?

        purchased =
          current_user
            .test_series_purchases
            .where(
              test_series: @test_series,
              payment_status: "paid",
              status: "Active"
            )
            .exists?

        return if purchased

        render json: {
          success: false,
          error: "You do not have access to this test series."
        }, status: :forbidden
      end

      def current_attempt
        current_user
          .test_series_attempts
          .where(test_series_test: @test)
          .in_progress
          .order(created_at: :desc)
          .first
      end

      def exam_time_expired?(attempt)
        return false unless attempt.started_at.present?

        duration_seconds =
          @test.duration.to_i * 60

        elapsed_seconds =
          (Time.current - attempt.started_at).to_i

        elapsed_seconds >= duration_seconds
      end

      def complete_attempt!(attempt)
        attempt.update!(
          status: "Completed",
          submitted_at: Time.current,
          completed_at: Time.current
        )
      end

      def test_json(test)
        {
          id: test.id,
          test_series_id: test.test_series_id,
          title: test.title,
          description: test.description,
          test_number: test.test_number,
          duration: test.duration,
          total_questions: test.test_series_questions.count,
          total_marks: test.test_series_questions.sum(:marks),
          status: test.status
        }
      end

      def question_json(question)
        {
          id: question.id,
          question_text: question.question_text,
          question_text_hindi: question.question_text_hindi,
          question_type: question.question_type,
          marks: question.marks,
          position: question.position,
          options: question.test_series_options.order(:position).map do |option|
            {
              id: option.id,
              option_text: option.option_text,
              option_text_hindi: option.option_text_hindi,
              position: option.position
            }
          end
        }
      end

      def attempt_json(attempt)
        duration_seconds =
          @test.duration.to_i * 60

        elapsed_seconds =
          if attempt.started_at.present?
            (Time.current - attempt.started_at).to_i
          else
            0
          end

        remaining_seconds =
          [duration_seconds - elapsed_seconds, 0].max

        total_questions =
          @test.test_series_questions.count

        answered_count =
          attempt.test_series_answers.count

        {
          id: attempt.id,
          test_series_test_id: attempt.test_series_test_id,
          status: attempt.status,
          started_at: attempt.started_at,
          submitted_at: attempt.submitted_at,
          completed_at: attempt.completed_at,
          duration_minutes: @test.duration,
          remaining_seconds: remaining_seconds,
          total_questions: total_questions,
          answered_count: answered_count,
          unanswered_count: total_questions - answered_count
        }
      end

      def render_finished_result(attempt)
        render_result(attempt)
      end

      def render_result(attempt)
        questions =
          @test
            .test_series_questions
            .includes(:test_series_options)
            .order(position: :asc)

        answers =
          attempt
            .test_series_answers
            .includes(
              :test_series_question,
              :test_series_option
            )

        answers_by_question =
          answers.index_by(&:test_series_question_id)

        total_marks =
          questions.sum(&:marks).to_f

        score =
          answers.sum do |answer|
            answer.marks_obtained.to_f
          end

        percentage =
          if total_marks.zero?
            0
          else
            (score / total_marks) * 100
          end

        correct_count =
          answers.count(&:is_correct?)

        wrong_count =
          answers.count { |answer| !answer.is_correct? }

        answered_count =
          answers.count

        unanswered_count =
          questions.count - answered_count

        render json: {
          success: true,
          data: {
            test: test_json(@test),

            attempt: {
              id: attempt.id,
              status: attempt.status,
              score: score,
              total_marks: total_marks,
              percentage: percentage.round(2),
              started_at: attempt.started_at,
              submitted_at: attempt.submitted_at,
              completed_at: attempt.completed_at
            },

            summary: {
              total_questions: questions.count,
              answered: answered_count,
              unanswered: unanswered_count,
              correct: correct_count,
              wrong: wrong_count
            },

            answers: questions.map do |question|
              answer =
                answers_by_question[question.id]

              correct_option =
                question
                  .test_series_options
                  .find(&:is_correct?)

              {
                question_id: question.id,
                question_text: question.question_text,
                question_text_hindi: question.question_text_hindi,

                selected_option_id:
                  answer&.test_series_option_id,

                selected_text:
                  answer&.test_series_option&.option_text,

                selected_text_hindi:
                  answer&.test_series_option&.option_text_hindi,

                correct_option_id:
                  correct_option&.id,

                correct_text:
                  correct_option&.option_text,

                correct_text_hindi:
                  correct_option&.option_text_hindi,

                is_correct:
                  answer&.is_correct,

                marks_obtained:
                  answer&.marks_obtained || 0,

                explanation:
                  question.explanation,

                explanation_hindi:
                  question.explanation_hindi
              }
            end
          }
        }, status: :ok
      end
    end
  end
end