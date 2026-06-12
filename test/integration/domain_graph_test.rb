require "test_helper"

class DomainGraphTest < ActionDispatch::IntegrationTest
  test "renders the domain graph as json" do
    get "/seeder_kit/domain_graph"

    assert_response :success
    assert_equal "application/json", response.media_type
    refute_match(/preview|run|execution|export|named scenario/i, response.body)

    graph = JSON.parse(response.body)

    assert_kind_of Array, graph.fetch("models")
    assert_equal [ "User", "Post", "Comment" ], graph.fetch("creation_order")

    post = graph.fetch("models").find { |model| model.fetch("name") == "Post" }

    assert_equal [ "User" ], post.fetch("dependencies")
    assert_equal [ "Comment" ], post.fetch("dependents")
  end
end
