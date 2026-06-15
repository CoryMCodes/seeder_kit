require "test_helper"

module SeederKit
  class ScenarioRegistryTest < ActiveSupport::TestCase
    setup do
      SeederKit.scenario_registry.clear
    end

    test "registers a scenario with name description and plan" do
      definition = SeederKit.scenario "User with posts" do
        description "Creates one user with two posts."
        plan(
          entities: [
            {
              ref: "user",
              model: "User",
              attributes: { name: "Alice", email: "alice@example.com" }
            }
          ]
        )
      end

      assert_equal "User with posts", definition.name
      assert_equal "Creates one user with two posts.", definition.description
      assert_equal 1, definition.plan.fetch(:entities).length
    end

    test "lists registered scenarios" do
      first = SeederKit.scenario("First") { description "First scenario" }
      second = SeederKit.scenario("Second") { description "Second scenario" }

      assert_equal [ first, second ], SeederKit.scenarios
      assert_equal [ first, second ], SeederKit.scenarios
    end

    test "rejects normalized duplicate names before evaluating the replacement block" do
      original = SeederKit.scenario(:demo) { description "Original" }
      replacement_evaluated = false

      error = assert_raises(ScenarioRegistry::DuplicateScenarioNameError) do
        SeederKit.scenario("demo") do
          replacement_evaluated = true
          description "Replacement"
        end
      end

      assert_same Errors::DuplicateScenarioNameError, ScenarioRegistry::DuplicateScenarioNameError
      assert_equal "duplicate_scenario_name", error.code
      assert_equal({ scenario_name: "demo" }, error.metadata)
      assert_equal "SeederKit scenario is already registered: demo", error.message
      refute replacement_evaluated
      assert_same original, SeederKit.scenarios.first
      assert_equal [ "demo" ], SeederKit.scenarios.map(&:name)

      SeederKit.scenario_registry.clear

      assert_empty SeederKit.scenarios
    end

    test "registration listing lookup and duplicate rejection do not write or mutate caller plans" do
      static_plan = {
        entities: [
          {
            ref: "user",
            model: "User",
            attributes: { email: "unchanged@example.com" }
          }
        ]
      }
      original_plan = Marshal.load(Marshal.dump(static_plan))

      assert_no_difference -> { User.count } do
        first = SeederKit.scenario("First") { plan static_plan }
        second = SeederKit.scenario("Second") { plan entities: [] }

        assert_equal [ first, second ], SeederKit.scenarios
        assert_same first, SeederKit.scenario_registry.fetch(:First)
        assert_raises(ScenarioRegistry::DuplicateScenarioNameError) do
          SeederKit.scenario("First") { raise "must not run" }
        end
      end

      assert_equal original_plan, static_plan
    end

    test "arbitrary registration block errors escape unchanged" do
      original = Class.new(StandardError).new("registration failed")
      cause = RuntimeError.new("root cause")

      error = assert_raises(original.class) do
        SeederKit.scenario("Broken") { raise original, cause: cause }
      end

      assert_same original, error
      assert_same cause, error.cause
      refute_respond_to error, :code
    end

    test "stores ordered child scenario includes" do
      first_bindings = { user_count: :user_count }
      second_bindings = { title: "Old news" }

      definition = SeederKit.scenario "Demo content" do
        include_scenario "Users with posts", **first_bindings
        include_scenario "Archived article", **second_bindings
      end

      first_include, second_include = definition.scenario_includes

      assert_equal({ user_count: :user_count }, first_bindings)
      assert_equal({ title: "Old news" }, second_bindings)
      assert definition.composed?
      assert_equal "Users with posts", first_include.name
      assert_equal({ user_count: :user_count }, first_include.input_bindings)
      assert_equal "Archived article", second_include.name
      assert_equal({ title: "Old news" }, second_include.input_bindings)
    end

    test "rejects adding includes after a plan" do
      error = assert_raises(ScenarioDefinition::MixedDefinitionError) do
        SeederKit.scenario "Mixed leaf first" do
          plan(entities: [])
          include_scenario "Users"
        end
      end

      assert_equal "Scenario Mixed leaf first cannot define both plan and include_scenario", error.message
    end

    test "rejects adding a plan after includes" do
      error = assert_raises(ScenarioDefinition::MixedDefinitionError) do
        SeederKit.scenario "Mixed composition first" do
          include_scenario "Users"
          plan(entities: [])
        end
      end

      assert_equal "Scenario Mixed composition first cannot define both plan and include_scenario", error.message
    end

    test "scenarios can define inputs" do
      definition = SeederKit.scenario "Parameterized users" do
        input :user_count, type: :integer, default: 5, description: "Number of users to create"
        input :published, type: :boolean, default: false
        input :name_prefix, type: :string
      end

      user_count = definition.input_definitions.fetch(:user_count)
      published = definition.input_definitions.fetch(:published)
      name_prefix = definition.input_definitions.fetch(:name_prefix)

      assert_same definition.input_definitions, definition.inputs
      assert_equal :user_count, user_count.name
      assert_equal :integer, user_count.type
      assert_equal 5, user_count.default
      assert_equal "Number of users to create", user_count.description
      assert_equal :boolean, published.type
      assert_equal :string, name_prefix.type
      assert name_prefix.required?
    end

    test "unsupported input definitions expose structured invalid input details" do
      error = assert_raises(ScenarioDefinition::InputError) do
        SeederKit.scenario "Unsupported input" do
          input :published_at, type: :datetime
        end
      end

      assert_same Errors::InvalidInputError, ScenarioDefinition::InputError
      assert_kind_of ArgumentError, error
      assert_equal "invalid_input", error.code
      assert_equal(
        {
          scenario_name: "Unsupported input",
          input_name: :published_at,
          expected_category: %i[integer string boolean],
          actual_category: :datetime
        },
        error.metadata
      )
      assert_equal "Unsupported input type for published_at: datetime", error.message
    end

    test "input defaults are used" do
      definition = SeederKit.scenario "Defaulted users" do
        input :user_count, type: :integer, default: 5
        input :name_prefix, type: :string, default: "User"
      end

      assert_equal(
        { user_count: 5, name_prefix: "User" },
        definition.resolve_inputs
      )
    end

    test "input overrides are applied" do
      definition = SeederKit.scenario "Overridden users" do
        input :user_count, type: :integer, default: 5
        input :name_prefix, type: :string, default: "User"
      end

      assert_equal(
        { user_count: 2, name_prefix: "Admin" },
        definition.resolve_inputs(user_count: 2, name_prefix: "Admin")
      )
    end

    test "string and boolean input overrides are validated" do
      definition = SeederKit.scenario "String and boolean inputs" do
        input :name_prefix, type: :string
        input :published, type: :boolean, default: false
      end

      assert_equal(
        { name_prefix: "Post", published: true },
        definition.resolve_inputs(name_prefix: "Post", published: true)
      )

      error = assert_raises(ScenarioDefinition::InputError) do
        definition.resolve_inputs(name_prefix: :post, published: "true")
      end

      assert_equal "Invalid input type for scenario String and boolean inputs: name_prefix must be string",
                   error.message

      error = assert_raises(ScenarioDefinition::InputError) do
        definition.resolve_inputs(name_prefix: "Post", published: "true")
      end

      assert_equal "Invalid input type for scenario String and boolean inputs: published must be boolean",
                   error.message
    end

    test "dynamic plan block receives resolved inputs" do
      received_inputs = nil

      definition = SeederKit.scenario "Dynamic users" do
        input :user_count, type: :integer, default: 5
        input :name_prefix, type: :string, default: "User"

        plan do |inputs|
          received_inputs = inputs

          {
            entities: [
              {
                ref: "user",
                model: "User",
                count: inputs.fetch(:user_count),
                attributes: {
                  name: inputs.fetch(:name_prefix),
                  email: "dynamic@example.com"
                }
              }
            ]
          }
        end
      end

      plan = definition.build_plan(user_count: 2)

      assert_equal({ user_count: 2, name_prefix: "User" }, received_inputs)
      assert_equal 2, plan.fetch(:entities).first.fetch(:count)
      assert_equal "User", plan.fetch(:entities).first.fetch(:attributes).fetch(:name)
    end

    test "unknown input overrides fail clearly" do
      SeederKit.scenario "Known inputs" do
        input :user_count, type: :integer, default: 5
      end

      error = assert_raises(ScenarioDefinition::InputError) do
        SeederKit.run_scenario("Known inputs", other_count: 2)
      end

      assert_equal "Unknown input for scenario Known inputs: other_count", error.message
      assert_equal "invalid_input", error.code
      assert_equal(
        {
          scenario_name: "Known inputs",
          input_name: :other_count,
          expected_category: "declared_input",
          actual_category: "unknown_input"
        },
        error.metadata
      )
    end

    test "missing required inputs fail clearly" do
      definition = SeederKit.scenario "Required inputs" do
        input :name_prefix, type: :string
      end

      error = assert_raises(ScenarioDefinition::InputError) do
        definition.resolve_inputs
      end

      assert_equal "Missing required input for scenario Required inputs: name_prefix", error.message
      assert_equal "invalid_input", error.code
      assert_equal "required_input", error.metadata.fetch(:expected_category)
      assert_equal "missing_input", error.metadata.fetch(:actual_category)
    end

    test "invalid input types fail clearly" do
      SeederKit.scenario "Typed inputs" do
        input :user_count, type: :integer, default: 5
      end

      error = assert_raises(ScenarioDefinition::InputError) do
        SeederKit.run_scenario("Typed inputs", user_count: "2")
      end

      assert_equal "Invalid input type for scenario Typed inputs: user_count must be integer", error.message
      assert_equal "invalid_input", error.code
      assert_equal :integer, error.metadata.fetch(:expected_category)
      assert_equal "String", error.metadata.fetch(:actual_category)
    end

    test "runs a registered scenario by name" do
      SeederKit.scenario "User with posts" do
        description "Creates one user with two posts."
        plan(
          entities: [
            {
              ref: "user",
              model: "User",
              attributes: { name: "Alice", email: "alice@example.com" }
            },
            {
              ref: "post",
              model: "Post",
              count: 2,
              attributes: { title: "Hello", body: "Test body" },
              belongs_to: { user: "user" }
            }
          ]
        )
      end

      assert_difference -> { User.count }, 1 do
        assert_difference -> { Post.count }, 2 do
          result = SeederKit.run_scenario("User with posts")

          user = result.records_by_ref.fetch("user").first
          posts = result.records_by_ref.fetch("post")

          assert_equal "Alice", user.name
          assert_equal [ user ], posts.map(&:user).uniq
        end
      end
    end

    test "run_scenario executes the generated plan successfully" do
      SeederKit.scenario "Parameterized user with posts" do
        input :user_count, type: :integer, default: 1
        input :posts_per_user, type: :integer, default: 3

        plan do |inputs|
          {
            entities: [
              {
                ref: "user",
                model: "User",
                count: inputs.fetch(:user_count),
                attributes: { name: "Parameterized", email: "parameterized@example.com" }
              },
              {
                ref: "post",
                model: "Post",
                count: inputs.fetch(:user_count) * inputs.fetch(:posts_per_user),
                attributes: { title: "Parameterized post", body: "Test body" },
                belongs_to: { user: "user" }
              }
            ]
          }
        end
      end

      assert_difference -> { User.count }, 2 do
        assert_difference -> { Post.count }, 8 do
          result = SeederKit.run_scenario(
            "Parameterized user with posts",
            user_count: 2,
            posts_per_user: 4
          )

          users = result.records_by_ref.fetch("user")
          posts = result.records_by_ref.fetch("post")

          assert_equal 2, users.length
          assert_equal 8, posts.length
          assert_equal users, posts.map(&:user).uniq
        end
      end
    end

    test "raises a clear error when running an unknown scenario" do
      error = assert_raises(ScenarioRegistry::UnknownScenarioError) do
        SeederKit.run_scenario("Missing scenario")
      end

      assert_equal "Unknown SeederKit scenario: Missing scenario", error.message
      assert_same Errors::UnknownScenarioError, ScenarioRegistry::UnknownScenarioError
      assert_equal "unknown_scenario", error.code
      assert_equal({ scenario_name: "Missing scenario" }, error.metadata)
      assert_equal(
        {
          "code" => "unknown_scenario",
          "message" => "Unknown SeederKit scenario: Missing scenario",
          "metadata" => { "scenario_name" => "Missing scenario" }
        },
        error.to_h
      )
    end

    test "scenario execution uses the existing validation path" do
      SeederKit.scenario "Invalid plan" do
        plan(
          entities: [
            {
              ref: "user",
              model: "User",
              attributes: { missing_attribute: "invalid" }
            }
          ]
        )
      end

      error = assert_raises(BasicScenarioValidator::ValidationError) do
        SeederKit.run_scenario("Invalid plan")
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
