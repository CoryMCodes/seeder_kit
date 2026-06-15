require "test_helper"

module SeederKit
  class ScenarioExecutorTest < ActiveSupport::TestCase
    test "creates related records and returns created refs" do
      plan = {
        entities: [
          {
            ref: "user",
            model: "User",
            count: 1,
            attributes: { name: "Alice", email: "alice@example.com" }
          },
          {
            ref: "post",
            model: "Post",
            count: 2,
            attributes: { title: "Hello", body: "Test body" },
            belongs_to: { user: "user" }
          },
          {
            ref: "comment",
            model: "Comment",
            count: 2,
            attributes: { body: "Useful comment" },
            belongs_to: { post: "post" }
          }
        ]
      }

      assert_difference -> { User.count }, 1 do
        assert_difference -> { Post.count }, 2 do
          assert_difference -> { Comment.count }, 2 do
            result = SeederKit.run(plan)

            user = result.records_by_ref.fetch("user").first
            posts = result.records_by_ref.fetch("post")
            comments = result.records_by_ref.fetch("comment")

            assert_equal "Alice", user.name
            assert_equal [ user ], posts.map(&:user).uniq
            assert_equal posts, comments.map(&:post)
          end
        end
      end
    end

    test "rolls back all records when execution fails" do
      plan = {
        entities: [
          {
            ref: "user",
            model: "User",
            attributes: { name: "Rollback", email: "rollback@example.com" }
          },
          {
            ref: "post",
            model: "Post",
            attributes: { body: "Missing title" },
            belongs_to: { user: "user" }
          }
        ]
      }

      assert_no_difference -> { User.count } do
        assert_no_difference -> { Post.count } do
          error = assert_raises(ActiveRecord::RecordInvalid) do
            SeederKit.run(plan)
          end

          assert_match(/Validation failed/, error.message)
          refute_respond_to error, :code
        end
      end
    end
  end
end
