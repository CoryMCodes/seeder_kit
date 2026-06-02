module SeederKit
  class ScenarioDefinition
    UNSET = Object.new.freeze
    SUPPORTED_INPUT_TYPES = %i[integer string boolean].freeze

    InputDefinition = Data.define(:name, :type, :default, :description) do
      def required?
        default.equal?(ScenarioDefinition::UNSET)
      end
    end
    IncludeDefinition = Data.define(:name, :input_bindings)

    class InputError < ArgumentError; end
    class MixedDefinitionError < ArgumentError; end

    attr_reader :name, :input_definitions, :scenario_includes

    def initialize(name)
      @name = name.to_s
      @description = nil
      @plan = nil
      @plan_defined = false
      @input_definitions = {}
      @scenario_includes = []
    end

    def evaluate(&block)
      instance_eval(&block) if block

      self
    end

    def description(value = UNSET)
      @description = value.to_s unless value.equal?(UNSET)

      @description
    end

    def inputs
      input_definitions
    end

    def input(name, type:, default: UNSET, description: nil)
      normalized_name = normalize_input_name(name)
      normalized_type = type.respond_to?(:to_sym) ? type.to_sym : type

      unless SUPPORTED_INPUT_TYPES.include?(normalized_type)
        raise InputError, "Unsupported input type for #{normalized_name}: #{type}"
      end

      input_definitions[normalized_name] = InputDefinition.new(
        name: normalized_name,
        type: normalized_type,
        default: default,
        description: description
      )
    end

    def plan(value = UNSET, &block)
      if block && !value.equal?(UNSET)
        raise ArgumentError, "Provide a static plan or a plan block, not both"
      end

      unless value.equal?(UNSET) && !block
        raise MixedDefinitionError, mixed_definition_message if composed?

        @plan = block || value
        @plan_defined = true
      end

      @plan
    end

    def include_scenario(name, **input_bindings)
      raise MixedDefinitionError, mixed_definition_message if @plan_defined

      scenario_includes << IncludeDefinition.new(name: name.to_s, input_bindings: input_bindings.dup)
    end

    def composed?
      scenario_includes.any?
    end

    def build_plan(overrides = {})
      resolved_inputs = resolve_inputs(overrides)

      return @plan.call(resolved_inputs) if @plan.respond_to?(:call)

      @plan
    end

    def resolve_inputs(overrides = {})
      normalized_overrides = normalize_overrides(overrides)
      unknown_inputs = normalized_overrides.keys - input_definitions.keys

      if unknown_inputs.any?
        raise InputError, "Unknown input for scenario #{name}: #{unknown_inputs.first}"
      end

      input_definitions.each_with_object({}) do |(input_name, definition), resolved|
        value = normalized_overrides.fetch(input_name) do
          if definition.required?
            raise InputError, "Missing required input for scenario #{name}: #{input_name}"
          end

          definition.default
        end

        validate_input_type(definition, value)
        resolved[input_name] = value
      end
    end

    private

    def mixed_definition_message
      "Scenario #{name} cannot define both plan and include_scenario"
    end

    def normalize_overrides(overrides)
      overrides.to_h.transform_keys { |key| normalize_input_name(key) }
    end

    def normalize_input_name(input_name)
      input_name.to_sym
    end

    def validate_input_type(definition, value)
      valid = case definition.type
              when :integer
                value.is_a?(Integer)
              when :string
                value.is_a?(String)
              when :boolean
                value == true || value == false
              end

      return if valid

      raise InputError,
            "Invalid input type for scenario #{name}: #{definition.name} must be #{definition.type}"
    end
  end
end
