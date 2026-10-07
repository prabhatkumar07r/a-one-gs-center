module Api
  module V1
    class TestSeriesController < Api::ApplicationController
      before_action :set_test_series, only: [:show]

      # GET /api/v1/test_series
      def index
        test_series =
          TestSeries
            .active
            .order(created_at: :desc)

        if params[:search].present?
          search = "%#{params[:search].strip}%"

          test_series =
            test_series.where(
              "title ILIKE :search OR language ILIKE :search OR exam_name ILIKE :search",
              search: search
            )
        end

        if params[:mode].present? &&
           params[:mode].to_s.downcase != "all"

          mode =
            params[:mode].to_s.downcase == "online" ? "Online" : "Offline"

          test_series = test_series.where(mode: mode)
        end

        if params[:language].present? &&
           params[:language].to_s.downcase != "all"

          test_series =
            test_series.where(
              "LOWER(language) = ?",
              params[:language].to_s.downcase
            )
        end

        render json: {
          success: true,
          data: {
            total: test_series.count,
            test_series: test_series.map do |series|
              series_json(series)
            end
          }
        }, status: :ok
      end

      # GET /api/v1/test_series/:id
      def show
        tests =
          @test_series
            .test_series_tests
            .active
            .includes(test_series_questions: :test_series_options)
            .order(test_number: :asc)

        has_access = access_to_series?

        render json: {
          success: true,
          data: {
            test_series: series_json(
              @test_series,
              include_access: true,
              has_access: has_access
            ),

            access: {
              allowed: has_access,
              reason: has_access ? nil : "Purchase required."
            },

            tests: tests.map do |test|
              test_json(test)
            end
          }
        }, status: :ok
      end

      private

      def set_test_series
        @test_series =
          TestSeries
            .active
            .find(params[:id])
      end

      def access_to_series?
        return true if @test_series.free?

        current_user
          .test_series_purchases
          .where(
            test_series: @test_series,
            payment_status: "paid",
            status: "Active"
          )
          .exists?
      end

      def series_json(series, include_access: false, has_access: nil)
        data = {
          id: series.id,
          title: series.title,
          description: series.description,
          exam_name: series.exam_name,
          mode: series.mode,
          language: series.language,
          price: series.price,
          original_price: series.original_price,
          discount: series.discount,
          status: series.status,
          registration_ended: series.registration_ended,
          test_count: series.test_count,
          question_count: series.question_count,
          total_questions: series.total_questions,
          total_marks: series.total_marks
        }

        if include_access
          data[:free] = series.free?
          data[:premium] = series.premium?
          data[:has_access] = has_access
        end

        data
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
    end
  end
end