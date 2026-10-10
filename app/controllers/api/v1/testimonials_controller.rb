# app/controllers/api/v1/testimonials_controller.rb

module Api
  module V1
    class TestimonialsController < Api::ApplicationController
      def index
        # Only records explicitly marked as active, approved, or published.
        testimonials = Testimonial
          .where("LOWER(status) IN (?)", %w[active approved published])
          .order(:display_order, created_at: :desc)

        render json: {
          success: true,
          data: {
            testimonials: testimonials.map do |testimonial|
              testimonial_json(testimonial)
            end
          }
        }, status: :ok
      end

      private

      def testimonial_json(testimonial)
        host = ENV.fetch("APP_HOST", "https://aonegscenter.com")

        {
          id: testimonial.id,
          student_name: testimonial.student_name,
          message: testimonial.message,
          rating: testimonial.rating,
          student_photo_url: testimonial.student_photo.attached? ?
            Rails.application.routes.url_helpers.rails_blob_url(
              testimonial.student_photo,
              host: host
            ) : nil
        }
      end
    end
  end
end