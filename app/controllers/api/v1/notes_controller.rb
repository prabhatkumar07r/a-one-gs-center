# app/controllers/api/v1/notes_controller.rb
# पूरा controller with all skips:

module Api
  module V1
    class NotesController < Api::ApplicationController
      # Skip ALL authentication callbacks
    
      # protect_from_forgery with: :null_session, if: -> { request.format.json? }
      
      def index
        notes = Note.all.order(created_at: :desc)
        render json: {
          success: true,
          count: notes.count,
          notes: notes.as_json(only: [:id, :title, :description, :category, :subject])
        }
      end
      
      def show
        note = Note.find_by(id: params[:id])
        if note
          render json: { success: true, note: note.as_json }
        else
          render json: { error: "Note not found" }, status: :not_found
        end
      end
      def download
  note = Note.find_by(id: params[:id])

  unless note
    return render json: {
      success: false,
      error: "Note not found."
    }, status: :not_found
  end

  unless note.pdf_file.attached?
    return render json: {
      success: false,
      error: "PDF file is not available."
    }, status: :not_found
  end

  redirect_to rails_blob_path(
    note.pdf_file,
    disposition: "inline"
  )
end
      
      def create
        note = Note.new(note_params)
        if note.save
          render json: { success: true, note: note }, status: :created
        else
          render json: { errors: note.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      def update
        note = Note.find_by(id: params[:id])
        unless note
          return render json: { error: "Note not found" }, status: :not_found
        end
        if note.update(note_params)
          render json: { success: true, note: note }
        else
          render json: { errors: note.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      def destroy
        note = Note.find_by(id: params[:id])
        unless note
          return render json: { error: "Note not found" }, status: :not_found
        end
        note.destroy
        render json: { success: true, message: "Note deleted" }
      end
      
      private
      
      def note_params
        params.permit(:title, :description, :category, :subject)
      end
    end
  end
end