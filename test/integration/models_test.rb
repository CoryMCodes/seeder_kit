require "test_helper"

class ModelsTest < ActionDispatch::IntegrationTest
  test "renders discovered models as diagnostic json" do
    get "/seeder_kit/models"

    assert_response :success
    assert_equal "application/json", response.media_type
    refute_match(/preview|run|execution|export|named scenario/i, response.body)

    schema = JSON.parse(response.body)

    assert_equal [ "Comment", "Post", "User" ], schema.fetch("models").pluck("name").sort
  end
end
