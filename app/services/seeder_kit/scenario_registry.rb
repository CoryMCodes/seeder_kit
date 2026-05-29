module SeederKit
  class ScenarioRegistry
    class UnknownScenarioError < KeyError; end

    def initialize
      @definitions_by_name = {}
    end

    def register(name, &block)
      definition = ScenarioDefinition.new(name).evaluate(&block)

      definitions_by_name[definition.name] = definition

      definition
    end

    def all
      definitions_by_name.values
    end

    def fetch(name)
      definitions_by_name.fetch(name.to_s) do
        raise UnknownScenarioError, "Unknown SeederKit scenario: #{name}"
      end
    end

    def run(name, **inputs)
      SeederKit.run(fetch(name).build_plan(inputs))
    end

    def clear
      definitions_by_name.clear
    end

    private

    attr_reader :definitions_by_name
  end
end
