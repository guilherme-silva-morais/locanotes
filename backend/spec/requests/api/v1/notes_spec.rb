require "rails_helper"

RSpec.describe "Api::V1::Notes", type: :request do
  let(:user) { create(:user) }
  let(:user_session) { create(:session, user: user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{JwtService.encode_access(user_session)}" } }

  describe "GET /api/v1/notes" do
    it "returns 401 without authentication" do
      get "/api/v1/notes"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the user's notes in recent-first order" do
      old    = create(:note, user: user, created_at: 2.days.ago)
      newer  = create(:note, user: user, created_at: 1.day.ago)
      newest = create(:note, user: user, created_at: Time.current)

      get "/api/v1/notes", headers: auth_headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"].map { |n| n["id"] }).to eq([ newest.id, newer.id, old.id ])
      expect(body).to include("next_cursor", "has_more")
    end

    it "does not include notes owned by other users" do
      create(:note, user: user, title: "Mine")
      create(:note, user: create(:user), title: "Theirs")

      get "/api/v1/notes", headers: auth_headers
      titles = JSON.parse(response.body)["data"].map { |n| n["title"] }
      expect(titles).to eq([ "Mine" ])
    end

    it "returns an empty data array when there are no notes" do
      get "/api/v1/notes", headers: auth_headers
      expect(JSON.parse(response.body)["data"]).to eq([])
    end
  end

  describe "GET /api/v1/notes/:id" do
    it "returns 401 without authentication" do
      get "/api/v1/notes/#{create(:note, user: user).id}"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the note when it belongs to the user" do
      note = create(:note, user: user, title: "Hello", content: "Body")
      get "/api/v1/notes/#{note.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to include("id" => note.id, "title" => "Hello", "content" => "Body")
      expect(body).to include("created_at", "updated_at")
    end

    it "returns 404 when the note belongs to another user (no existence leak)" do
      foreign = create(:note, user: create(:user))
      get "/api/v1/notes/#{foreign.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when the note does not exist" do
      get "/api/v1/notes/999999", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/notes" do
    it "returns 401 without authentication" do
      post "/api/v1/notes", params: { title: "x" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "creates a note owned by the current user and returns 201" do
      expect {
        post "/api/v1/notes",
             params: { title: "First note", content: "Hello world" },
             headers: auth_headers
      }.to change(user.notes, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body).to include("id", "title" => "First note", "content" => "Hello world")
    end

    it "accepts a title with exactly 120 characters" do
      post "/api/v1/notes",
           params: { title: "a" * 120 },
           headers: auth_headers
      expect(response).to have_http_status(:created)
    end

    it "rejects a title with 121 characters (422 with localized error)" do
      post "/api/v1/notes",
           params: { title: "a" * 121 },
           headers: auth_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["errors"]["title"]).to be_present
    end

    it "rejects an empty title with a localized error" do
      post "/api/v1/notes", params: { title: "" }, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_content)
      msgs = JSON.parse(response.body)["errors"]["title"].join
      expect(msgs.downcase).to match(/branco|caractere/)
    end

    it "rejects a whitespace-only title (strip leaves it empty)" do
      post "/api/v1/notes", params: { title: "    " }, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "accepts content with exactly 10000 characters" do
      post "/api/v1/notes",
           params: { title: "x", content: "a" * 10_000 },
           headers: auth_headers
      expect(response).to have_http_status(:created)
    end

    it "rejects content with 10001 characters" do
      post "/api/v1/notes",
           params: { title: "x", content: "a" * 10_001 },
           headers: auth_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["errors"]["content"]).to be_present
    end

    it "persists unicode characters in title and content" do
      post "/api/v1/notes",
           params: { title: "Título café ☕", content: "Conteúdo 📝" },
           headers: auth_headers
      body = JSON.parse(response.body)
      expect(body["title"]).to eq("Título café ☕")
      expect(body["content"]).to eq("Conteúdo 📝")
    end

    it "returns errors in en when Accept-Language: en is sent" do
      post "/api/v1/notes",
           params: { title: "" },
           headers: auth_headers.merge("Accept-Language" => "en")
      msgs = JSON.parse(response.body)["errors"]["title"].join
      expect(msgs.downcase).to match(/blank|character/)
    end
  end

  describe "PATCH /api/v1/notes/:id" do
    let(:note) { create(:note, user: user, title: "Original") }

    it "returns 401 without authentication" do
      patch "/api/v1/notes/#{note.id}", params: { title: "x" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "updates a note owned by the user" do
      patch "/api/v1/notes/#{note.id}",
            params: { title: "Updated", content: "New body" },
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(note.reload.title).to eq("Updated")
      expect(note.reload.content).to eq("New body")
    end

    it "allows a partial update (title only)" do
      patch "/api/v1/notes/#{note.id}", params: { title: "Just title" }, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(note.reload.title).to eq("Just title")
    end

    it "returns 404 when the note belongs to another user (no existence leak)" do
      foreign = create(:note, user: create(:user))
      patch "/api/v1/notes/#{foreign.id}", params: { title: "Hacked" }, headers: auth_headers
      expect(response).to have_http_status(:not_found)
      expect(foreign.reload.title).not_to eq("Hacked")
    end

    it "returns 422 when validations fail" do
      patch "/api/v1/notes/#{note.id}",
            params: { title: "a" * 121 },
            headers: auth_headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /api/v1/notes/:id" do
    let!(:note) { create(:note, user: user) }

    it "returns 401 without authentication" do
      delete "/api/v1/notes/#{note.id}"
      expect(response).to have_http_status(:unauthorized)
    end

    it "deletes a note owned by the user and returns 204" do
      expect {
        delete "/api/v1/notes/#{note.id}", headers: auth_headers
      }.to change(Note, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "returns 404 when the note belongs to another user (no existence leak)" do
      foreign = create(:note, user: create(:user))
      expect {
        delete "/api/v1/notes/#{foreign.id}", headers: auth_headers
      }.not_to change(Note, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when the note does not exist" do
      delete "/api/v1/notes/999999", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
