class StudyNotesController < ApplicationController
  layout :select_layout

  before_action :authenticate_user!
  before_action :authorize_admin_or_teacher
  before_action :set_note, only: [:show, :edit, :update, :destroy, :download]

  # =========================================================
  # GET /study_notes
  # =========================================================

  def index

    if current_user.admin?

      @notes =
        Note
          .includes(:user, :video, playlist: :course)
          .order(created_at: :desc)

    else

      @notes =
        Note
          .joins(playlist: :course)
          .where(
            courses: {
              teacher_id: current_user.teacher.id
            }
          )
          .includes(:user, :video, playlist: :course)
          .order(created_at: :desc)

    end

  end


  # =========================================================
  # GET /study_notes/new
  # =========================================================

  def new

    @note = Note.new

    load_courses

  end


  # =========================================================
  # GET /study_notes/:id
  # =========================================================

  def show

  end


  # =========================================================
  # GET /study_notes/:id/edit
  # =========================================================

  def edit

    load_courses

  end


  # =========================================================
  # GET /study_notes/:id/download
  # =========================================================

  def download

    if @note.pdf_file.attached?

      redirect_to rails_blob_url(
        @note.pdf_file,
        disposition: "attachment"
      )

    else

      redirect_to study_notes_path,
                  alert: "No file attached."

    end

  end


  # =========================================================
  # POST /study_notes
  # =========================================================

  def create

    @note = Note.new(note_params)

    @note.user = current_user


    if @note.save

      redirect_to study_notes_path,
                  notice: "Study Note uploaded successfully."

    else

      load_courses

      render :new,
             status: :unprocessable_entity

    end

  end


  # =========================================================
  # PATCH /study_notes/:id
  # =========================================================

  def update

    if @note.update(note_params)

      redirect_to study_notes_path,
                  notice: "Study note updated successfully."

    else

      load_courses

      render :edit,
             status: :unprocessable_entity

    end

  end


  # =========================================================
  # DELETE /study_notes/:id
  # =========================================================

  def destroy

    @note.destroy

    redirect_to study_notes_path,
                notice: "Study note deleted successfully."

  end


  # =========================================================
  # AJAX — PLAYLISTS
  #
  # GET /study_notes/playlists?course_id=5
  # =========================================================

  def playlists

    course =
      accessible_courses.find_by(
        id: params[:course_id]
      )


    unless course

      render json: [],
             status: :unprocessable_entity

      return

    end


    playlists =
      Playlist
        .where(course_id: course.id)
        .order(:position)


    render json:
      playlists.map { |playlist|

        {
          id: playlist.id,
          title: playlist.title
        }

      }

  end


  # =========================================================
  # AJAX — VIDEOS
  #
  # GET /study_notes/videos?playlist_id=10
  # =========================================================

  def videos

    playlist =
      accessible_playlists.find_by(
        id: params[:playlist_id]
      )


    unless playlist

      render json: [],
             status: :unprocessable_entity

      return

    end


    videos =
      Video
        .where(playlist_id: playlist.id)
        .where(status: :active)
        .order(:position)


    render json:
      videos.map { |video|

        {
          id: video.id,
          title: video.title,
          position: video.position,
          thumbnail: video.youtube_thumbnail
        }

      }

  end


  private


  # =========================================================
  # LAYOUT
  # =========================================================

  def select_layout

    current_user.admin? ? "admin" : "teacher"

  end


  # =========================================================
  # LOAD COURSES
  # =========================================================

  def load_courses

    @courses =
      accessible_courses
        .includes(:playlists)
        .order(:Course_name)

  end


  # =========================================================
  # ACCESSIBLE COURSES
  #
  # ADMIN:
  #   All courses
  #
  # TEACHER:
  #   Only their courses
  # =========================================================

  def accessible_courses

    if current_user.admin?

      Course.all

    elsif current_user.teacher?

      current_user.teacher.courses

    else

      Course.none

    end

  end


  # =========================================================
  # ACCESSIBLE PLAYLISTS
  # =========================================================

  def accessible_playlists

    Playlist
      .joins(:course)
      .merge(accessible_courses)

  end


  # =========================================================
  # SET NOTE
  # =========================================================

  def set_note

    @note =
      Note.find(params[:id])

  end


  # =========================================================
  # STRONG PARAMETERS
  # =========================================================

  def note_params

    params.require(:note).permit(
      :playlist_id,
      :video_id,
      :description,
      :pdf_file,
      :title
    )

  end


  # =========================================================
  # ADMIN / TEACHER AUTHORIZATION
  # =========================================================

  def authorize_admin_or_teacher

    unless current_user.admin? ||
           current_user.teacher?

      redirect_to root_path,
                  alert:
                    "Only Admin or Teacher can manage study notes."

    end

  end

end