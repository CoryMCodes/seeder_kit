require "test_helper"

module SeederKit
  class ScenarioPreviewTest < ActiveSupport::TestCase
    setup do
      SeederKit.scenario_registry.clear
    end

    test "preview_scenario resolves default inputs" do
      SeederKit.scenario "Default preview" do
        input :user_count, type: :integer, default: 2
        input :name_prefix, type: :string, default: "Default"

        plan do |inputs|
          {
            entities: [
              {
                ref: "user",
                model: "User",
                count: inputs.fetch(:user_count),
                attributes: {
                  name: inputs.fetch(:name_prefix),
                  email: "default-preview@example.com"
                }
              }
            ]
          }
        end
      end

      result = SeederKit.preview_scenario("Default preview")
      user_summary = result.entities.fetch(0)

      assert result.valid?
      assert_equal 2, result.total_records
      assert_equal 2, user_summary.count
      assert_equal [ "name", "email" ], user_summary.attribute_keys
      assert_equal "Default", result.plan.entities.first.attributes.fetch("name")
    end

    test "preview_scenario applies overrides" do
      SeederKit.scenario "Override preview" do
        input :user_count, type: :integer, default: 1
        input :posts_per_user, type: :integer, default: 2

        plan do |inputs|
          {
            entities: [
              {
                ref: "user",
                model: "User",
                count: inputs.fetch(:user_count),
                attributes: { name: "Override", email: "override-preview@example.com" }
              },
              {
                ref: "post",
                model: "Post",
                count: inputs.fetch(:user_count) * inputs.fetch(:posts_per_user),
                attributes: { title: "Preview post", body: "Preview body" },
                belongs_to: { user: "user" }
              }
            ]
          }
        end
      end

      result = SeederKit.preview_scenario("Override preview", user_count: 3, posts_per_user: 4)
      post_summary = result.entities.fetch(1)

      assert_equal 15, result.total_records
      assert_equal 12, post_summary.count
      assert_equal({ "user" => "user" }, post_summary.belongs_to)
    end

    test "preview returns total record count" do
      result = SeederKit.preview(
        entities: [
          {
            ref: "user",
            model: "User",
            count: 2,
            attributes: { name: "Preview", email: "preview-count@example.com" }
          },
          {
            ref: "post",
            model: "Post",
            count: 3,
            attributes: { title: "Preview post", body: "Preview body" },
            belongs_to: { user: "user" }
          },
          {
            ref: "comment",
            model: "Comment",
            count: 4,
            attributes: { body: "Preview comment" },
            belongs_to: { post: "post" }
          }
        ]
      )

      assert_equal 9, result.total_records
    end

    test "preview does not create records" do
      plan = {
        entities: [
          {
            ref: "user",
            model: "User",
            attributes: { name: "No write", email: "no-write-preview@example.com" }
          },
          {
            ref: "post",
            model: "Post",
            count: 2,
            attributes: { title: "No write post", body: "No write body" },
            belongs_to: { user: "user" }
          }
        ]
      }

      assert_no_difference -> { User.count } do
        assert_no_difference -> { Post.count } do
          SeederKit.preview(plan)
        end
      end
    end

    test "invalid preview uses existing validation errors" do
      error = assert_raises(BasicScenarioValidator::ValidationError) do
        SeederKit.preview(
          entities: [
            {
              ref: "user",
              model: "User",
              attributes: { missing_attribute: "invalid" }
            }
          ]
        )
      end

      assert_includes error.errors, {
        code: "unknown_attribute",
        ref: "user",
        model: "User",
        attribute: "missing_attribute"
      }
    end
  end
end
