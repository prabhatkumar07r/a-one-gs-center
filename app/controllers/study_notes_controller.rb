class StudyNotesController < ApplicationController
  layout :select_layout

  before_action :authenticate_user!
  before_action :authorize_admin_or_teacher
  before_action :set_note, only: [:show, :edit, :update, :destroy]

  # GET /study_notes
  def index
    if current_user.admin?
      @notes = Note.includes(:user, playlist: :course)
                   .order(created_at: :desc)
    else
      @notes = Note.joins(playlist: :course)
                   .where(courses: { teacher_id: current_user.teacher.id })
                   .includes(:user, playlist: :course)
                   .order(created_at: :desc)
    end
  end

  def videos
    videos = Video.where(playlist_id: params[:playlist_id])
    render json: videos.select(:id, :title)
  end

  # GET /study_notes/new
  def new
    @note = Note.new
    load_courses
  end

  # GET /study_notes/:id
  def show
  end

  # GET /study_notes/:id/edit
  def edit
    load_courses
  end

  def download
    if @note.pdf_file.attached?
      redirect_to rails_blob_url(@note.pdf_file, disposition: "attachment")
    else
      redirect_to study_notes_path, alert: "No file attached."
    end
  end

  # POST /study_notes
  def create
    @note = Note.new(note_params)
    @note.user = current_user

    if @note.save
      redirect_to study_notes_path,
                  notice: "Study Note uploaded successfully."
    else
      load_courses
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /study_notes/:id
  def update
    if @note.update(note_params)
      redirect_to study_notes_path,
                  notice: "Study note updated successfully."
    else
      load_courses
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /study_notes/:id
  def destroy
    @note.destroy
    redirect_to study_notes_path,
                notice: "Study note deleted successfully."
  end

  # AJAX
  def playlists
    playlists = Playlist.where(course_id: params[:course_id]).order(:position)
    render json: playlists.select(:id, :title)
  end

  private

  def select_layout
    current_user.admin? ? "admin" : "teacher"
  end

  def load_courses
    if current_user.admin?
      @courses = Course.includes(:playlists).order(:Course_name)
    elsif current_user.teacher?
      @courses = current_user.teacher.courses
                             .includes(:playlists)
                             .order(:Course_name)
    else
      @courses = Course.none
    end
  end

  def set_note
    @note = Note.find(params[:id])
  end

  def note_params
    params.require(:note).permit(
      :playlist_id,
      :video_id,
      :description,
      :pdf_file,
      :title
    )
  end

  def authorize_admin_or_teacher
    unless current_user.admin? || current_user.teacher?
      redirect_to root_path,
                  alert: "Only Admin or Teacher can manage study notes."
    end
  end
end