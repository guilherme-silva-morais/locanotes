module Api
  module V1
    module Auth
      class SessionsController < ApplicationController
        allow_unauthenticated_access only: %i[create refresh]

        # POST /api/v1/auth/login
        def create
          user = User.authenticate_by(
            email_address: params[:email_address],
            password: params[:password]
          )

          unless user
            return render json: { error: I18n.t("auth.invalid_credentials") },
                          status: :unauthorized
          end

          session = start_new_session_for(user)
          render json: token_response(user, session), status: :ok
        end

        # POST /api/v1/auth/refresh
        def refresh
          token = params[:refresh_token]
          return render_unauthorized_json if token.blank?

          payload = JwtService.decode(token, expected_type: "refresh")
          session = Session.find_by(id: payload["jti"])
          return render_unauthorized_json unless session

          render json: { access_token: JwtService.encode_access(session) }, status: :ok
        rescue JwtService::Error
          render_unauthorized_json
        end

        # DELETE /api/v1/auth/logout
        def destroy
          terminate_session
          head :no_content
        end

        private

          def token_response(user, session)
            {
              access_token: JwtService.encode_access(session),
              refresh_token: JwtService.encode_refresh(session),
              user: { id: user.id, email_address: user.email_address }
            }
          end

          def render_unauthorized_json
            render json: { error: I18n.t("auth.unauthorized") }, status: :unauthorized
          end
      end
    end
  end
end
