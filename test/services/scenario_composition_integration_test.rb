require "test_helper"

module SeederKit
  class ScenarioCompositionIntegrationTest < ActiveSupport::TestCase
    setup do
      SeederKit.scenario_registry.clear
    end

    test "preview_scenario composes leaf plans without writes" do
      register_user_leaf("First user", ref: "first_user", email: "first@example.com")
      register_user_leaf("Second user", ref: "second_user", email: "second@example.com")

      SeederKit.scenario "Preview users" do
        include_scenario "First user"
        include_scenario "Second user"
      end

      assert_no_difference -> { User.count } do
        result = SeederKit.preview_scenario("Preview users")

        assert_equal 2, result.total_records
        assert_equal [ "first_user", "second_user" ], result.entities.map(&:ref)
      end
    end

    test "run_scenario executes one composed plan" do
      register_user_leaf("First user", ref: "first_user", email: "first@example.com")
      register_user_leaf("Second user", ref: "second_user", email: "second@example.com")

      SeederKit.scenario "Run users" do
        include_scenario "First user"
        include_scenario "Second user"
      end

      assert_difference -> { User.count }, 2 do
        result = SeederKit.run_scenario("Run users")

        assert_equal [ "first_user", "second_user" ], result.records_by_ref.keys
      end
    end

    test "preview rejects duplicate refs after composition" do
      register_user_leaf("First user", ref: "user", email: "first@example.com")
      register_user_leaf("Second user", ref: "user", email: "second@example.com")

      SeederKit.scenario "Duplicate preview" do
        include_scenario "First user"
        include_scenario "Second user"
      end

      error = assert_raises(BasicScenarioValidator::ValidationError) do
        SeederKit.preview_scenario("Duplicate preview")
      end

      assert error.errors.any? { |validation_error| validation_error[:code] == "duplicate_ref" }
    end

    test "run rejects duplicate refs before writes" do
      register_user_leaf("First user", ref: "user", email: "first@example.com")
      register_user_leaf("Second user", ref: "user", email: "second@example.com")

      SeederKit.scenario "Duplicate run" do
        include_scenario "First user"
        include_scenario "Second user"
      end

      assert_no_difference -> { User.count } do
        error = assert_raises(BasicScenarioValidator::ValidationError) do
          SeederKit.run_scenario("Duplicate run")
        end

        assert error.errors.any? { |validation_error| validation_error[:code] == "duplicate_ref" }
      end
    end

    test "composed execution rolls back earlier children when a later child fails" do
      register_user_leaf("Valid user", ref: "valid_user", email: "valid@example.com")

      SeederKit.scenario "Invalid user" do
        plan(
          entities: [
            { ref: "invalid_user", model: "User", attributes: { name: "Missing email" } }
          ]
        )
      end

      SeederKit.scenario "Rollback users" do
        include_scenario "Valid user"
        include_scenario "Invalid user"
      end

      assert_no_difference -> { User.count } do
        assert_raises(ActiveRecord::RecordInvalid) do
          SeederKit.run_scenario("Rollback users")
        end
      end
    end

    private

    def register_user_leaf(name, ref:, email:)
      SeederKit.scenario name do
        plan(
          entities: [
            { ref: ref, model: "User", attributes: { email: email } }
          ]
        )
      end
    end
  end
end
