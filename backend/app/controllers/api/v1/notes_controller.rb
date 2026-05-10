module Api
  module V1
    class NotesController < ApplicationController
      before_action :load_note, only: %i[show update destroy]

      def index
        notes = policy_scope(Note).recent_first
        render json: {
          data: notes.map { |n| serialize_note(n) },
          next_cursor: nil,
          has_more: false
        }
      end

      def show
        authorize @note
        render json: serialize_note(@note)
      end

      def create
        note = Current.user.notes.build(note_params)
        if note.save
          render json: serialize_note(note), status: :created
        else
          render json: { errors: note.errors.as_json }, status: :unprocessable_content
        end
      end

      def update
        authorize @note
        if @note.update(note_params)
          render json: serialize_note(@note)
        else
          render json: { errors: @note.errors.as_json }, status: :unprocessable_content
        end
      end

      def destroy
        authorize @note
        @note.destroy
        head :no_content
      end

      private
        def load_note
          @note = Note.find_by(id: params[:id])
          head(:not_found) and return unless @note
        end

        def note_params
          params.permit(:title, :content)
        end

        def serialize_note(note)
          {
            id: note.id,
            title: note.title,
            content: note.content,
            created_at: note.created_at.iso8601,
            updated_at: note.updated_at.iso8601
          }
        end
    end
  end
end
