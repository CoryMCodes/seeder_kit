module SeederKit
  class ScenarioPreview
    EntitySummary = Data.define(:ref, :model, :count, :attribute_keys, :belongs_to) do
      def attributes_keys
        attribute_keys
      end
    end

    Result = Data.define(:plan, :entities, :total_records, :valid) do
      def valid?
        valid
      end
    end

    def initialize(validator: BasicScenarioValidator.new)
      @validator = validator
    end

    def call(input)
      plan = input.is_a?(ScenarioPlan) ? input : ScenarioPlan.build(input)

      validator.call(plan)

      Result.new(
        plan: plan,
        entities: plan.entities.map { |entity| summary_for(entity) },
        total_records: plan.entities.sum(&:count),
        valid: true
      )
    end

    private

    attr_reader :validator

    def summary_for(entity)
      EntitySummary.new(
        ref: entity.ref,
        model: entity.model,
        count: entity.count,
        attribute_keys: entity.attributes.keys,
        belongs_to: entity.belongs_to.dup
      )
    end
  end
end
