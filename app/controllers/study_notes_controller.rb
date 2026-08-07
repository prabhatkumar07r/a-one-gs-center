class StudyNotesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin_or_teacher
  before_action :set_note, only: [:show, :edit, :update, :destroy]

  # GET /study_notes
  def index
  @notes = Note.includes(:user, playlist: :course)
               .order(created_at: :desc)
end
def videos
  videos = Video.where(playlist_id: params[:playlist_id])

  render json: videos.select(:id, :title)
end

  # GET /study_notes/new
  def new
  @note = Note.new
  
  @courses = Course.includes(:playlists).order(:Course_name)
end

  # GET /study_notes/:id
  def show
  end

  # GET /study_notes/:id/edit
 def edit
  @courses = Course.order(:Course_name)
end

def download
  @note = Note.find(params[:id])

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
    redirect_to study_notes_path, notice: "Study Note uploaded successfully."
  else
    @courses = Course.all
    render :new, status: :unprocessable_entity
  end
end

  # PATCH/PUT /study_notes/:id
  def update
    if @note.update(note_params)
      redirect_to study_notes_path,
                  notice: "Study note updated successfully."
    else
      @courses = Course.order(:Course_name)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /study_notes/:id
  def destroy
    @note.destroy

    redirect_to study_notes_path,
                notice: "Study note deleted successfully."
  end

  # AJAX: Load playlists by course
  def playlists
    playlists = Playlist.where(course_id: params[:course_id]).order(:position)

    render json: playlists.select(:id, :title)
  end

  private

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