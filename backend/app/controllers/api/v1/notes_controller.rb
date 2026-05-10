module Api
  module V1
    class NotesController < ApplicationController
      before_action :load_note, only: %i[show update destroy]

      def index
        result = CursorPagination.new(
          policy_scope(Note).recent_first,
          cursor: params[:cursor],
          limit: params[:limit]
        ).call

        render json: {
          data: result.records.map { |n| serialize_note(n) },
          next_cursor: result.next_cursor,
          has_more: result.has_more
        }
      rescue CursorPagination::InvalidCursor
        render json: { error: I18n.t("notes.invalid_cursor") }, status: :bad_request
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
