class NotesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_note, only: [:show, :preview, :download]

  # GET /resources
 def index
  @notes = Note.includes(:user, playlist: :course)
               .order(created_at: :desc)
end

  # GET /notes/:id
  def show
  end

def preview

  if @note.pdf_file.attached?

    @pdf_url = rails_blob_path(
      @note.pdf_file,
      disposition: "inline"
    )

    render :preview

  else

    redirect_to resources_path,
                alert: "PDF not found."

  end

end

  # GET /notes/:id/download
def download

  if @note.pdf_file.attached?

    @note.increment!(:download_count)

    send_data @note.pdf_file.download,
              filename: @note.pdf_file.filename.to_s,
              type: "application/pdf",
              disposition: "attachment"

  else

    redirect_to resources_path,
                alert: "PDF file not found."

  end

end

  private

  def set_note
    @note = Note.find(params[:id])
  end
end