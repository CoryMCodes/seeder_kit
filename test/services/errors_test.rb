require "test_helper"

module SeederKit
  class ErrorsTest < ActiveSupport::TestCase
    ERROR_CODES = {
      Errors::UnknownScenarioError => "unknown_scenario",
      Errors::InvalidInputError => "invalid_input",
      Errors::ScenarioValidationError => "scenario_validation_failed",
      Errors::ProductionExecutionRefusedError => "production_execution_refused",
      Errors::ExecutionFailureError => "execution_failed",
      Errors::DuplicateScenarioNameError => "duplicate_scenario_name"
    }.freeze

    test "typed domain errors expose stable codes messages and metadata" do
      ERROR_CODES.each do |error_class, code|
        error = error_class.new("Actionable message", metadata: { scenario_name: "demo" })

        assert_equal code, error.code
        assert_equal "Actionable message", error.message
        assert_equal({ scenario_name: "demo" }, error.metadata)
      end
    end

    test "serialization recursively stringifies keys and returns fresh structures" do
      metadata = {
        scenario_name: "demo",
        validation: [
          { code: "missing_ref", details: { expected: :present } }
        ]
      }
      error = Errors::UnknownScenarioError.new("Unknown", metadata: metadata)

      first = error.to_h
      second = error.to_h

      assert_equal(
        {
          "code" => "unknown_scenario",
          "message" => "Unknown",
          "metadata" => {
            "scenario_name" => "demo",
            "validation" => [
              { "code" => "missing_ref", "details" => { "expected" => :present } }
            ]
          }
        },
        first
      )
      refute_same first, second
      refute_same first.fetch("metadata"), second.fetch("metadata")
      refute_same first.dig("metadata", "validation"), second.dig("metadata", "validation")
    end

    test "construction and serialization do not mutate or retain caller owned metadata" do
      scenario_name = +"demo"
      metadata = { scenario_name: scenario_name, nested: [ { values: [ +"one" ] } ] }
      original = Marshal.load(Marshal.dump(metadata))
      error = Errors::InvalidInputError.new("Invalid", metadata: metadata)

      metadata[:nested].first[:values] << "two"
      scenario_name << " changed"
      serialized = error.to_h
      serialized.dig("metadata", "nested").first.fetch("values") << "three"

      assert_equal original, error.metadata
      assert_equal original, error.to_h.fetch("metadata").deep_symbolize_keys
    end

    test "typed categories preserve useful exception superclass compatibility" do
      assert_operator Errors::UnknownScenarioError, :<, KeyError
      assert_operator Errors::InvalidInputError, :<, ArgumentError
      assert_operator Errors::DuplicateScenarioNameError, :<, ArgumentError
      assert_operator Errors::ScenarioValidationError, :<, StandardError
    end
  end
end
