module SeederKit
  class ScenarioComposer
    class NestedCompositionError < ArgumentError; end
    class MissingParentInputError < ArgumentError; end
    class CrossChildReferenceError < ArgumentError; end

    def initialize(registry:)
      @registry = registry
    end

    def call(definition, overrides = {})
      return definition.build_plan(overrides) unless definition.composed?

      parent_inputs = definition.resolve_inputs(overrides)

      {
        entities: definition.scenario_includes.flat_map do |scenario_include|
          entities_for(definition, scenario_include, parent_inputs)
        end
      }
    end

    private

    attr_reader :registry

    def entities_for(parent, scenario_include, parent_inputs)
      child = registry.fetch(scenario_include.name)

      if child.composed?
        raise NestedCompositionError,
              "Scenario #{parent.name} cannot include composed scenario #{child.name}"
      end

      child_plan = ScenarioPlan.build(
        child.build_plan(resolve_child_overrides(parent, scenario_include, parent_inputs))
      )

      validate_internal_refs!(parent, child, child_plan)

      child_plan.entities.map { |entity| entity_hash(entity) }
    end

    def resolve_child_overrides(parent, scenario_include, parent_inputs)
      scenario_include.input_bindings.transform_values do |binding|
        next binding unless binding.is_a?(Symbol)

        unless parent_inputs.key?(binding)
          raise MissingParentInputError,
                "Unknown parent input for scenario #{parent.name}: #{binding}"
        end

        parent_inputs.fetch(binding)
      end
    end

    def validate_internal_refs!(parent, child, child_plan)
      child_refs = child_plan.entities.map(&:ref)

      child_plan.entities.each do |entity|
        entity.belongs_to.each_value do |target_ref|
          next if child_refs.include?(target_ref.to_s)

          raise CrossChildReferenceError,
                "Scenario #{parent.name} includes #{child.name} with an external ref: #{target_ref}"
        end
      end
    end

    def entity_hash(entity)
      {
        ref: entity.ref,
        model: entity.model,
        count: entity.count,
        attributes: entity.attributes.dup,
        belongs_to: entity.belongs_to.dup
      }
    end
  end
end
