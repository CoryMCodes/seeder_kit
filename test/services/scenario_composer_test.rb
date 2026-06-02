require "test_helper"

module SeederKit
  class ScenarioComposerTest < ActiveSupport::TestCase
    setup do
      @registry = ScenarioRegistry.new
      @composer = ScenarioComposer.new(registry: @registry)
    end

    test "merges leaf entities in include order with mappings literals and child defaults" do
      @registry.register "Users" do
        input :user_count, type: :integer, default: 1

        plan do |inputs|
          {
            entities: [
              { ref: "users", model: "User", count: inputs.fetch(:user_count) }
            ]
          }
        end
      end

      @registry.register "Archived article" do
        input :title, type: :string
        input :status, type: :string, default: "archived"

        plan do |inputs|
          {
            entities: [
              {
                ref: "archived_post",
                model: "Post",
                attributes: {
                  title: inputs.fetch(:title),
                  status: inputs.fetch(:status)
                }
              }
            ]
          }
        end
      end

      definition = @registry.register "Demo content" do
        input :demo_user_count, type: :integer, default: 2

        include_scenario "Users", user_count: :demo_user_count
        include_scenario "Archived article", title: "Old news"
      end

      plan = @composer.call(definition, demo_user_count: 4)

      assert_equal [ "users", "archived_post" ], plan.fetch(:entities).map { |entity| entity.fetch(:ref) }
      assert_equal 4, plan.fetch(:entities).fetch(0).fetch(:count)
      assert_equal(
        { "title" => "Old news", "status" => "archived" },
        plan.fetch(:entities).fetch(1).fetch(:attributes)
      )
    end

    test "composition does not write records" do
      definition = @registry.register "No writes" do
        include_scenario "User leaf"
      end

      @registry.register "User leaf" do
        plan(
          entities: [
            {
              ref: "user",
              model: "User",
              attributes: { email: "compose-only@example.com" }
            }
          ]
        )
      end

      assert_no_difference -> { User.count } do
        @composer.call(definition)
      end
    end

    test "rejects a missing parent input mapping" do
      @registry.register "Users" do
        input :user_count, type: :integer
        plan(entities: [])
      end

      definition = @registry.register "Broken mapping" do
        include_scenario "Users", user_count: :missing_count
      end

      error = assert_raises(ScenarioComposer::MissingParentInputError) do
        @composer.call(definition)
      end

      assert_equal "Unknown parent input for scenario Broken mapping: missing_count", error.message
    end

    test "reuses child required input errors" do
      @registry.register "Users" do
        input :user_count, type: :integer
        plan(entities: [])
      end

      definition = @registry.register "Missing child input" do
        include_scenario "Users"
      end

      error = assert_raises(ScenarioDefinition::InputError) do
        @composer.call(definition)
      end

      assert_equal "Missing required input for scenario Users: user_count", error.message
    end

    test "reuses child invalid input errors" do
      @registry.register "Users" do
        input :user_count, type: :integer
        plan(entities: [])
      end

      definition = @registry.register "Invalid child input" do
        include_scenario "Users", user_count: "four"
      end

      error = assert_raises(ScenarioDefinition::InputError) do
        @composer.call(definition)
      end

      assert_equal "Invalid input type for scenario Users: user_count must be integer", error.message
    end

    test "reuses the registry unknown scenario error" do
      definition = @registry.register "Missing child parent" do
        include_scenario "Missing child"
      end

      error = assert_raises(ScenarioRegistry::UnknownScenarioError) do
        @composer.call(definition)
      end

      assert_equal "Unknown SeederKit scenario: Missing child", error.message
    end

    test "rejects nested composition" do
      @registry.register "Leaf" do
        plan(entities: [])
      end

      @registry.register "Nested child" do
        include_scenario "Leaf"
      end

      definition = @registry.register "Nested parent" do
        include_scenario "Nested child"
      end

      error = assert_raises(ScenarioComposer::NestedCompositionError) do
        @composer.call(definition)
      end

      assert_equal "Scenario Nested parent cannot include composed scenario Nested child", error.message
    end

    test "rejects cross child refs" do
      @registry.register "Users" do
        plan(
          entities: [
            { ref: "user", model: "User" }
          ]
        )
      end

      @registry.register "Posts" do
        plan(
          entities: [
            { ref: "post", model: "Post", belongs_to: { user: "user" } }
          ]
        )
      end

      definition = @registry.register "Cross child refs" do
        include_scenario "Users"
        include_scenario "Posts"
      end

      error = assert_raises(ScenarioComposer::CrossChildReferenceError) do
        @composer.call(definition)
      end

      assert_equal "Scenario Cross child refs includes Posts with an external ref: user", error.message
    end
  end
end
