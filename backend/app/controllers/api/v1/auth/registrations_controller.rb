module Api
  module V1
    module Auth
      class RegistrationsController < ApplicationController
        allow_unauthenticated_access only: :create

        def create
          user = User.new(user_params)

          if user.save
            session = start_new_session_for(user)
            render json: token_response(user, session), status: :created
          else
            render json: { errors: user.errors.as_json }, status: :unprocessable_content
          end
        end

        private

          def user_params
            params.permit(:email_address, :password, :password_confirmation)
          end

          def token_response(user, session)
            {
              access_token: JwtService.encode_access(session),
              refresh_token: JwtService.encode_refresh(session),
              user: { id: user.id, email_address: user.email_address }
            }
          end
      end
    end
  end
end
