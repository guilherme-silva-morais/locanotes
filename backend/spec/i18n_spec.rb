require "rails_helper"

RSpec.describe "I18n configuration" do
  it "lists pt-BR and en as available locales" do
    expect(I18n.available_locales).to contain_exactly(:en, :"pt-BR")
  end

  it "uses pt-BR as the default locale" do
    expect(I18n.default_locale).to eq(:"pt-BR")
  end

  it "translates a known message in pt-BR" do
    expect(I18n.t("errors.messages.blank", locale: :"pt-BR"))
      .to eq("não pode ficar em branco")
  end

  it "translates the same message in en" do
    expect(I18n.t("errors.messages.blank", locale: :en))
      .to eq("can't be blank")
  end

  it "falls back to en when a key is missing in pt-BR" do
    # Add a temporary en-only key and ensure pt-BR falls back to it
    I18n.backend.store_translations(:en, fallback_only_key: "fallback works")
    expect(I18n.t("fallback_only_key", locale: :"pt-BR")).to eq("fallback works")
  end
end

RSpec.describe "Locale negotiation via Accept-Language", type: :request do
  # The `/up` endpoint is mounted on Rails::HealthController which doesn't
  # inherit from ApplicationController, so it bypasses our before_action.
  # We exercise the locale_from_accept_language_header helper directly by
  # building a controller instance and stubbing the request.
  let(:controller) do
    Class.new(ApplicationController) do
      def index
        render plain: I18n.locale.to_s
      end
    end.new
  end

  def parse_locale(header)
    request = ActionDispatch::TestRequest.create
    request.headers["Accept-Language"] = header
    controller.instance_variable_set(:@_request, request)
    controller.send(:locale_from_accept_language_header)
  end

  it "returns pt-BR for 'pt-BR' header" do
    expect(parse_locale("pt-BR")).to eq(:"pt-BR")
  end

  it "returns en for 'en' header" do
    expect(parse_locale("en")).to eq(:en)
  end

  it "picks the first supported locale in a weighted list" do
    expect(parse_locale("fr-FR,en;q=0.9,pt-BR;q=0.5")).to eq(:en)
  end

  it "returns nil when no supported locale is found (caller falls back to default)" do
    expect(parse_locale("fr-FR,de")).to be_nil
  end

  it "returns nil for an empty header" do
    expect(parse_locale("")).to be_nil
  end
end
