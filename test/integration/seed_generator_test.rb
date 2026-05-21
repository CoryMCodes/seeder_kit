require "test_helper"

class SeedGeneratorTest < ActionDispatch::IntegrationTest
  test "renders the seed generator as the engine root" do
    get "/seeder_kit"

    assert_response :success
    assert_select "h1", "Seed Generator"
    assert_select "textarea[name=schema]"
  end

  test "generates seeds from pasted schema text" do
    post "/seeder_kit/generate", params: { schema: File.read(Rails.root.join("db/schema.rb")) }

    assert_response :success
    assert_select "textarea#seed-output", /User\.create!/
    assert_select "textarea#seed-output", /Post\.create!/
    assert_select "textarea#seed-output", /user_id: user\.id/
  end

  test "shows a validation error for blank schema text" do
    post "/seeder_kit/generate", params: { schema: "" }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", "Paste a Rails schema.rb file to generate seeds."
  end
end
