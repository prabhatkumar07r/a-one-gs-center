module Api
  module V1
    class TestSeriesAttemptsController < Api::ApplicationController
      # GET
      # /api/v1/test_series/attempts
      #
      # Returns the logged-in student's test attempt history
      # along with overall test-series progress.
      def index
        attempts =
          current_user
            .test_series_attempts
            .includes(
              test_series_test: :test_series,
              test_series_answers: []
            )
            .order(created_at: :desc)

        attempt_items =
          attempts.map do |attempt|
            test = attempt.test_series_test
            test_series = test.test_series

            total_marks =
              test
                .test_series_questions
                .sum(:marks)
                .to_f

            score =
              attempt
                .test_series_answers
                .sum do |answer|
                  answer.marks_obtained.to_f
                end

            percentage =
              if total_marks.zero?
                0
              else
                (score / total_marks) * 100
              end

            answered =
              attempt.test_series_answers.count

            total_questions =
              test.test_series_questions.count

            correct =
              attempt
                .test_series_answers
                .count(&:is_correct?)

            wrong =
              attempt
                .test_series_answers
                .count do |answer|
                  !answer.is_correct?
                end

            {
              id: attempt.id,
              status: attempt.status,
              started_at: attempt.started_at,
              submitted_at: attempt.submitted_at,
              completed_at: attempt.completed_at,

              score: score,
              total_marks: total_marks,
              percentage: percentage.round(2),

              answered: answered,
              unanswered: [total_questions - answered, 0].max,
              correct: correct,
              wrong: wrong,

              test: {
                id: test.id,
                title: test.title,
                test_number: test.test_number,
                duration: test.duration,
                total_questions: total_questions,
                total_marks: total_marks
              },

              test_series: {
                id: test_series.id,
                title: test_series.title,
                exam_name: test_series.exam_name
              }
            }
          end

        completed_attempts =
          attempts.select(&:completed?)

        completed_test_ids =
          completed_attempts
            .map(&:test_series_test_id)
            .uniq

        total_tests =
          TestSeriesTest
            .joins(:test_series)
            .merge(TestSeries.active)
            .count

        completed_tests =
          completed_test_ids.length

        total_attempts =
          attempts.count

        total_score =
          completed_attempts.sum do |attempt|
            attempt
              .test_series_answers
              .sum do |answer|
                answer.marks_obtained.to_f
              end
          end

        overall_total_marks =
          completed_attempts.sum do |attempt|
            attempt
              .test_series_test
              .test_series_questions
              .sum(:marks)
              .to_f
          end

        overall_percentage =
          if overall_total_marks.zero?
            0
          else
            (total_score / overall_total_marks) * 100
          end

        best_percentage =
          completed_attempts.map do |attempt|
            test =
              attempt.test_series_test

            total_marks =
              test.test_series_questions.sum(:marks).to_f

            score =
              attempt.test_series_answers.sum do |answer|
                answer.marks_obtained.to_f
              end

            next 0 if total_marks.zero?

            (score / total_marks) * 100
          end.max || 0

        render json: {
          success: true,
          data: {
            attempts: attempt_items,

            progress: {
              total_attempts: total_attempts,
              completed_tests: completed_tests,
              total_tests: total_tests,
              overall_percentage: overall_percentage.round(2),
              best_percentage: best_percentage.round(2)
            }
          }
        }, status: :ok
      end
    end
  end
end
