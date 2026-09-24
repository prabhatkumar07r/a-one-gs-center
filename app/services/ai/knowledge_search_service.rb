module Ai
  class KnowledgeSearchService
    MAX_RESULTS_PER_TYPE = 5
    MAX_SEARCH_TERMS = 6

    STOP_WORDS = %w[
      a
      an
      and
      are
      as
      at
      be
      can
      course
      courses
      do
      does
      for
      from
      how
      i
      in
      is
      it
      me
      of
      on
      or
      please
      tell
      the
      this
      to
      what
      where
      which
      who
      why
      with
      about
      available
      show
      give
      want
      need
      explain
      information
      details
      videos
      video
      lessons
      lesson
      classes
      class
      related
      know
      much
      many
      have
      has
      there
      fee
      fees
      price
      pricing
      cost
      amount
      list
      find
      search
      enroll
      enrollment
      enrolled
      enrollments
      join
      admission
      buy
      purchase
      register
      registration
      get
      access
      can
      could
      should
      ke
      hai
      hain
      batao
      bataiye
      chahiye
      kya
      kaise
      meri
      mera
      mere
      mujhe
    ].freeze

    def initialize(user:)
      @user = user
      @enrollment_status_cache = {}
    end

    def call(query:)
      query = query.to_s.strip

      if query.blank?
        Rails.logger.info(
          "[A ONE AI] Knowledge catalog request: returning active courses."
        )

        return {
          courses: catalog_courses,
          playlists: [],
          videos: [],
          notes: [],
          resources: []
        }
      end

      search_terms = extract_search_terms(query)

      return empty_result if search_terms.empty?

      Rails.logger.info(
        "[A ONE AI] Knowledge search query: #{query.inspect}"
      )

      Rails.logger.info(
        "[A ONE AI] Knowledge search terms: #{search_terms.inspect}"
      )

      {
        courses: search_courses(search_terms, query),
        playlists: search_playlists(search_terms, query),
        videos: search_videos(search_terms, query),
        notes: search_notes(search_terms, query),
        resources: search_resources(search_terms, query)
      }
    end

    private

    attr_reader :user

    def catalog_courses
      courses =
        Course
          .where(status: "Active")
          .order(created_at: :desc)
          .first(MAX_RESULTS_PER_TYPE)

      preload_enrollment_statuses(courses)

      courses.map do |course|
        {
          id: course.id,
          name: course.Course_name,
          description: course.description,
          course_type: course.course_type,
          fee: course.fee,
          original_fee: course.original_fee,
          discount_percentage: course.discount_percentage,
          duration: course.duration,
          status: course.status,
          access: course_access(course),
          enrollment_status: enrollment_status(course),
          course_url: course_url(course)
        }
      end
    end

    def extract_search_terms(query)
      normalized =
        query
          .to_s
          .downcase
          .gsub(/[^\p{L}\p{N}\s]/, " ")
          .squeeze(" ")
          .strip

      normalized
        .split
        .reject { |word| STOP_WORDS.include?(word) }
        .select { |word| word.length >= 2 }
        .uniq
        .first(MAX_SEARCH_TERMS)
    end

    def normalize_text(value)
      value
        .to_s
        .downcase
        .gsub(/[^\p{L}\p{N}\s]/, " ")
        .squeeze(" ")
        .strip
    end

    def relevance_score(search_terms:, searchable_text:, exact_fields: [])
      text = normalize_text(searchable_text)

      return 0 if text.blank?

      score = 0

      normalized_terms = search_terms.join(" ")

      if normalized_terms.length >= 3 &&
         text.include?(normalized_terms)
        score += 100
      end

      matched_terms = 0

      search_terms.each do |term|
        normalized_term = normalize_text(term)

        next if normalized_term.blank?

        if text.include?(normalized_term)
          matched_terms += 1
          score += 20
        end
      end

      return 0 unless matched_terms == search_terms.length

      exact_fields.each do |field|
        field_text = normalize_text(field)

        next if field_text.blank?

        if search_terms.all? do |term|
             field_text.include?(normalize_text(term))
           end
          score += 50
        end
      end

      score
    end

    def search_courses(search_terms, query)
      courses =
        Course
          .where(status: "Active")
          .order(created_at: :desc)

      scored_courses =
        courses.filter_map do |course|
          searchable_text =
            [
              course.Course_name,
              course.description,
              course.course_type,
              course.learning_outcomes,
              course.requirements
            ].compact.join(" ")

          score =
            relevance_score(
              search_terms: search_terms,
              searchable_text: searchable_text,
              exact_fields: [
                course.Course_name
              ]
            )

          next if score <= 0

          [course, score]
        end

      results =
        scored_courses
          .sort_by { |course, score| [-score, -course.created_at.to_i] }
          .first(MAX_RESULTS_PER_TYPE)

      preload_enrollment_statuses(results.map(&:first))

      results.map do |course, _score|
        {
          id: course.id,
          name: course.Course_name,
          description: course.description,
          course_type: course.course_type,
          fee: course.fee,
          original_fee: course.original_fee,
          discount_percentage: course.discount_percentage,
          duration: course.duration,
          status: course.status,
          access: course_access(course),
          enrollment_status: enrollment_status(course),
          course_url: course_url(course)
        }
      end
    end

    def search_playlists(search_terms, query)
      playlists =
        Playlist
          .joins(:course)
          .where(courses: { status: "Active" })
          .includes(:course)
          .order("playlists.created_at DESC")

      scored_playlists =
        playlists.filter_map do |playlist|
          searchable_text =
            [
              playlist.title,
              playlist.description,
              playlist.course&.Course_name,
              playlist.course&.description
            ].compact.join(" ")

          score =
            relevance_score(
              search_terms: search_terms,
              searchable_text: searchable_text,
              exact_fields: [
                playlist.title,
                playlist.course&.Course_name
              ]
            )

          next if score <= 0

          [playlist, score]
        end

      results =
        scored_playlists
          .sort_by do |playlist, score|
            [-score, -playlist.created_at.to_i]
          end
          .first(MAX_RESULTS_PER_TYPE)

      preload_enrollment_statuses(
        results.map { |playlist, _score| playlist.course }.compact
      )

      results.map do |playlist, _score|
        {
          id: playlist.id,
          title: playlist.title,
          description: playlist.description,
          course_id: playlist.course_id,
          course_name: playlist.course&.Course_name,
          access: content_access(playlist.course),
          enrollment_status: enrollment_status(playlist.course)
        }
      end
    end

    def search_videos(search_terms, query)
      videos =
        Video
          .joins(:course)
          .where(courses: { status: "Active" })
          .where(status: "active")
          .includes(:course, :playlist)
          .order("videos.created_at DESC")

      scored_videos =
        videos.filter_map do |video|
          searchable_text =
            [
              video.title,
              video.description,
              video.course&.Course_name,
              video.course&.description,
              video.playlist&.title,
              video.playlist&.description
            ].compact.join(" ")

          score =
            relevance_score(
              search_terms: search_terms,
              searchable_text: searchable_text,
              exact_fields: [
                video.title,
                video.playlist&.title,
                video.course&.Course_name
              ]
            )

          next if score <= 0

          [video, score]
        end

      results =
        scored_videos
          .sort_by do |video, score|
            [-score, -video.created_at.to_i]
          end
          .first(MAX_RESULTS_PER_TYPE)

      preload_enrollment_statuses(
        results.map { |video, _score| video.course }.compact
      )

      results.filter_map do |video, _score|
        access = video_access(video)

        next if access == "locked"

        {
          id: video.id,
          title: video.title,
          description: video.description,
          course_id: video.course_id,
          course_name: video.course&.Course_name,
          playlist_id: video.playlist_id,
          playlist_name: video.playlist&.title,
          is_free: video.is_free?,
          status: video.status,
          access: access
        }
      end
    end

    def search_notes(search_terms, query)
      notes =
        Note
          .joins(playlist: :course)
          .where(courses: { status: "Active" })
          .includes(playlist: :course)
          .order("notes.created_at DESC")

      scored_notes =
        notes.filter_map do |note|
          searchable_text =
            [
              note.title,
              note.subject,
              note.category,
              note.description,
              note.playlist&.title,
              note.playlist&.description,
              note.playlist&.course&.Course_name
            ].compact.join(" ")

          score =
            relevance_score(
              search_terms: search_terms,
              searchable_text: searchable_text,
              exact_fields: [
                note.title,
                note.playlist&.title
              ]
            )

          next if score <= 0

          [note, score]
        end

      results =
        scored_notes
          .sort_by do |note, score|
            [-score, -note.created_at.to_i]
          end
          .first(MAX_RESULTS_PER_TYPE)

      preload_enrollment_statuses(
        results.map { |note, _score| note.playlist&.course }.compact
      )

      results.filter_map do |note, _score|
        course = note.playlist&.course
        access = content_access(course)

        next if access == "locked"

        {
          id: note.id,
          title: note.title,
          subject: note.subject,
          category: note.category,
          description: note.description,
          playlist_id: note.playlist_id,
          playlist_name: note.playlist&.title,
          course_id: course&.id,
          course_name: course&.Course_name,
          access: access
        }
      end
    end

    def search_resources(search_terms, query)
      resources =
        Resource
          .joins(playlist: :course)
          .where(courses: { status: "Active" })
          .includes(playlist: :course)
          .order("resources.created_at DESC")

      scored_resources =
        resources.filter_map do |resource|
          searchable_text =
            [
              resource.title,
              resource.description,
              resource.resource_type,
              resource.playlist&.title,
              resource.playlist&.description,
              resource.playlist&.course&.Course_name
            ].compact.join(" ")

          score =
            relevance_score(
              search_terms: search_terms,
              searchable_text: searchable_text,
              exact_fields: [
                resource.title,
                resource.playlist&.title
              ]
            )

          next if score <= 0

          [resource, score]
        end

      results =
        scored_resources
          .sort_by do |resource, score|
            [-score, -resource.created_at.to_i]
          end
          .first(MAX_RESULTS_PER_TYPE)

      preload_enrollment_statuses(
        results.map { |resource, _score| resource.playlist&.course }.compact
      )

      results.filter_map do |resource, _score|
        course = resource.playlist&.course
        access = content_access(course)

        next if access == "locked"

        {
          id: resource.id,
          title: resource.title,
          description: resource.description,
          resource_type: resource.resource_type,
          playlist_id: resource.playlist_id,
          playlist_name: resource.playlist&.title,
          course_id: course&.id,
          course_name: course&.Course_name,
          access: access
        }
      end
    end

    def preload_enrollment_statuses(courses)
      courses =
        Array(courses)
          .compact
          .uniq { |course| course.id }

      return if courses.empty?

      missing_course_ids =
        courses
          .map(&:id)
          .reject { |course_id| @enrollment_status_cache.key?(course_id) }

      return if missing_course_ids.empty?

      enrollments =
        Enrollment
          .where(
            user_id: user.id,
            course_id: missing_course_ids
          )
          .order(created_at: :desc)

      latest_by_course = {}

      enrollments.each do |enrollment|
        course_id = enrollment.course_id

        next if latest_by_course.key?(course_id)

        latest_by_course[course_id] =
          case enrollment.status.to_s.downcase
          when "approved"
            "approved"
          when "pending"
            "pending"
          else
            "not_enrolled"
          end
      end

      missing_course_ids.each do |course_id|
        @enrollment_status_cache[course_id] =
          latest_by_course.fetch(course_id, "not_enrolled")
      end
    end

    def course_access(course)
      return "free" if course.nil?
      return "free" if course.fee.to_f <= 0

      status = enrollment_status(course)

      return "enrolled" if status == "approved"

      "locked"
    end

    def content_access(course)
      return "free" if course.nil?
      return "free" if course.fee.to_f <= 0

      status = enrollment_status(course)

      return "enrolled" if status == "approved"

      "locked"
    end

    def video_access(video)
      return "free" if video.is_free?

      course = video.course

      return "free" if course && course.fee.to_f <= 0

      return "enrolled" if course && enrollment_status(course) == "approved"

      "locked"
    end

    def enrollment_status(course)
      return "not_enrolled" if course.nil?

      @enrollment_status_cache.fetch(course.id) do
        preload_enrollment_statuses([course])

        @enrollment_status_cache.fetch(
          course.id,
          "not_enrolled"
        )
      end
    end

    def course_url(course)
      return nil unless course

      "/courses/#{course.id}"
    end

    def empty_result
      {
        courses: [],
        playlists: [],
        videos: [],
        notes: [],
        resources: []
      }
    end
  end
end