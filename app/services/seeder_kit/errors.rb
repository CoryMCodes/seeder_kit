module SeederKit
  module Errors
    module DomainError
      attr_reader :code, :metadata

      def initialize(message = nil, metadata: {})
        @code = self.class::CODE
        @metadata = deep_duplicate(metadata)

        super(message)
      end

      def to_h
        {
          "code" => code,
          "message" => message,
          "metadata" => stringify_keys(metadata)
        }
      end

      private

      def deep_duplicate(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, nested_value), duplicate|
            duplicate[deep_duplicate(key)] = deep_duplicate(nested_value)
          end
        when Array
          value.map { |nested_value| deep_duplicate(nested_value) }
        else
          value.dup
        end
      rescue TypeError
        value
      end

      def stringify_keys(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, nested_value), stringified|
            stringified[key.to_s] = stringify_keys(nested_value)
          end
        when Array
          value.map { |nested_value| stringify_keys(nested_value) }
        else
          deep_duplicate(value)
        end
      end
    end

    class UnknownScenarioError < KeyError
      include DomainError

      CODE = "unknown_scenario"
    end

    class InvalidInputError < ArgumentError
      include DomainError

      CODE = "invalid_input"
    end

    class ScenarioValidationError < StandardError
      include DomainError

      CODE = "scenario_validation_failed"

      def initialize(message = "Scenario plan is invalid", metadata: nil)
        if message.is_a?(Array) && metadata.nil?
          metadata = { errors: message }
          message = "Scenario plan is invalid"
        end

        super(message, metadata: metadata || {})
      end

      def errors
        metadata.fetch(:errors, [])
      end
    end

    class ProductionExecutionRefusedError < StandardError
      include DomainError

      CODE = "production_execution_refused"
    end

    class ExecutionFailureError < StandardError
      include DomainError

      CODE = "execution_failed"
    end

    class DuplicateScenarioNameError < ArgumentError
      include DomainError

      CODE = "duplicate_scenario_name"
    end
  end
end
