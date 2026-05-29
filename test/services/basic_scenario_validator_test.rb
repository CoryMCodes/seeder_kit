require "test_helper"

module SeederKit
  class BasicScenarioValidatorTest < ActiveSupport::TestCase
    test "accepts a minimal valid relational plan" do
      plan = ScenarioPlan.build(
        entities: [
          { ref: "user", model: "User", attributes: { email: "alice@example.com" } },
          { ref: "post", model: "Post", attributes: { title: "Hello" }, belongs_to: { user: "user" } }
        ]
      )

      assert_equal true, BasicScenarioValidator.new.call(plan)
    end

    test "returns structured errors for invalid models attributes refs and ordering" do
      plan = ScenarioPlan.build(
        entities: [
          { ref: "post", model: "Post", attributes: { full_title: "Hello" }, belongs_to: { user: "user" } },
          { ref: "user", model: "User", count: 0, attributes: { email: "alice@example.com" } },
          { ref: "missing", model: "MissingModel" }
        ]
      )

      error = assert_raises(BasicScenarioValidator::ValidationError) do
        BasicScenarioValidator.new.call(plan)
      end

      assert_includes error.errors, {
        code: "unknown_attribute",
        ref: "post",
        model: "Post",
        attribute: "full_title"
      }
      assert_includes error.errors, {
        code: "ref_not_available",
        ref: "post",
        model: "Post",
        association: "user",
        target_ref: "user"
      }
      assert_includes error.errors, {
        code: "invalid_count",
        ref: "user",
        model: "User",
        count: 0
      }
      assert_includes error.errors, {
        code: "unknown_model",
        ref: "missing",
        model: "MissingModel"
      }
    end

    test "requires unique refs" do
      plan = ScenarioPlan.build(
        entities: [
          { ref: "user", model: "User" },
          { ref: "user", model: "User" }
        ]
      )

      error = assert_raises(BasicScenarioValidator::ValidationError) do
        BasicScenarioValidator.new.call(plan)
      end

      assert error.errors.any? { |validation_error| validation_error[:code] == "duplicate_ref" }
    end
  end
end
