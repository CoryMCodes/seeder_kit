module SeederKit
  class ScenarioRegistry
    UnknownScenarioError = Errors::UnknownScenarioError
    DuplicateScenarioNameError = Errors::DuplicateScenarioNameError

    def initialize
      @definitions_by_name = {}
    end

    def register(name, &block)
      normalized_name = name.to_s

      if definitions_by_name.key?(normalized_name)
        raise DuplicateScenarioNameError.new(
          "SeederKit scenario is already registered: #{normalized_name}",
          metadata: { scenario_name: normalized_name }
        )
      end

      definition = ScenarioDefinition.new(normalized_name).evaluate(&block)

      definitions_by_name[definition.name] = definition

      definition
    end

    def all
      definitions_by_name.values
    end

    def fetch(name)
      normalized_name = name.to_s

      definitions_by_name.fetch(normalized_name) do
        raise UnknownScenarioError.new(
          "Unknown SeederKit scenario: #{name}",
          metadata: { scenario_name: normalized_name }
        )
      end
    end

    def run(name, **inputs)
      SeederKit.run(build_plan(name, inputs))
    end

    def preview(name, **inputs)
      SeederKit.preview(build_plan(name, inputs))
    end

    def clear
      definitions_by_name.clear
    end

    private

    attr_reader :definitions_by_name

    def build_plan(name, inputs)
      ScenarioComposer.new(registry: self).call(fetch(name), inputs)
    end
  end
end
