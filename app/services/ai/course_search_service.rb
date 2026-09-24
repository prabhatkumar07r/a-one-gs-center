module Ai
  class CourseSearchService
    MAX_RESULTS = 10

    def initialize(user:)
      @user = user
    end

    def call(query: nil)
      courses = Course.where(status: "Active")

      if query.present?
        normalized_query = normalize_text(query)

        if normalized_query.present?
          # First try normal SQL matching.
          courses =
            courses.where(
              <<~SQL.squish,
                LOWER(REGEXP_REPLACE("Course_name", '\s+', ' ', 'g')) LIKE :query
                OR LOWER(REGEXP_REPLACE(COALESCE(description, ''), '\s+', ' ', 'g')) LIKE :query
                OR LOWER(REGEXP_REPLACE(COALESCE(course_type, ''), '\s+', ' ', 'g')) LIKE :query
              SQL
              query: "%#{normalized_query}%"
            )
        end
      end

      courses
        .order(created_at: :desc)
        .limit(MAX_RESULTS)
        .map do |course|
          serialize_course(course)
        end
    end

    private

    # =========================================================
    # NORMALIZE SEARCH TEXT
    # =========================================================

    def normalize_text(text)
      text
        .to_s
        .downcase
        .strip
        .gsub(/\s+/, " ")
    end

    # =========================================================
    # SERIALIZE COURSE
    # =========================================================

    def serialize_course(course)
      {
        id: course.id,
        name: normalize_display_text(course.Course_name),
        description: course.description,
        course_type: course.course_type,
        fee: course.fee,
        original_fee: course.original_fee,
        discount_percentage: course.discount_percentage,
        duration: course.duration,
        requirements: course.requirements,
        learning_outcomes: course.learning_outcomes,
        status: course.status
      }
    end

    # =========================================================
    # DISPLAY TEXT
    # =========================================================

    def normalize_display_text(text)
      text
        .to_s
        .gsub(/\s+/, " ")
        .strip
    end
  end
end