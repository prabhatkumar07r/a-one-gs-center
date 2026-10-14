# app/controllers/api/v1/teachers_controller.rb

module Api
  module V1
    class TeachersController < Api::ApplicationController
      def index
        teachers = Teacher.includes(:courses).order(:name)

        render json: {
          success: true,
          data: {
            teachers: teachers.map { |teacher| teacher_json(teacher) }
          }
        }, status: :ok
      end

      private


def teacher_json(teacher)
  host = ENV.fetch("APP_HOST", "https://aonegscenter.com")

  {
    id: teacher.id,
    name: teacher.name,
    subject: teacher.subject,
    qualification: teacher.qualification,
    designation: teacher.designation,
    experience: teacher.experience,
    bio: teacher.bio,
    photo_url: teacher.photo.attached? ?
      Rails.application.routes.url_helpers.rails_blob_url(
        teacher.photo,
        host: host
      ) : nil,
    facebook: teacher.facebook,
    instagram: teacher.instagram,
    linkedin: teacher.linkedin,
    gmail: teacher.gmail
  }
end

    end
  end
end
