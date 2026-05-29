module SeederKit
  class ScenarioExecutor
    Result = Data.define(:records_by_ref)

    def initialize(validator: BasicScenarioValidator.new)
      @validator = validator
    end

    def call(input)
      plan = input.is_a?(ScenarioPlan) ? input : ScenarioPlan.build(input)

      validator.call(plan)

      records_by_ref = {}

      ActiveRecord::Base.transaction do
        plan.entities.each do |entity|
          records_by_ref[entity.ref] = create_records(entity, records_by_ref)
        end
      end

      Result.new(records_by_ref: records_by_ref)
    end

    private

    attr_reader :validator

    def create_records(entity, records_by_ref)
      model_class = entity.model.constantize

      entity.count.times.map do |index|
        model_class.create!(attributes_for(entity, records_by_ref, index))
      end
    end

    def attributes_for(entity, records_by_ref, index)
      attributes = entity.attributes.dup

      entity.belongs_to.each do |association_name, target_ref|
        attributes[association_name] = record_for(records_by_ref.fetch(target_ref.to_s), index)
      end

      attributes
    end

    def record_for(records, index)
      records[index] || records.first
    end
  end
end
