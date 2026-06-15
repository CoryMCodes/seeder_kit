require "set"

module SeederKit
  class BasicScenarioValidator
    ValidationError = Errors::ScenarioValidationError

    def call(plan)
      errors = []
      refs = plan.entities.map(&:ref)

      validate_refs(plan, refs, errors)
      validate_entities(plan, refs, errors)
      validate_dependency_order(plan, errors)

      raise ValidationError.new("Scenario plan is invalid", metadata: { errors: errors }) if errors.any?

      true
    end

    private

    def validate_refs(plan, refs, errors)
      plan.entities.each do |entity|
        if entity.ref.empty?
          errors << { code: "missing_ref", model: entity.model }
        end

        if entity.model.empty?
          errors << { code: "missing_model", ref: entity.ref }
        end

        next if refs.count(entity.ref) == 1

        errors << { code: "duplicate_ref", ref: entity.ref }
      end
    end

    def validate_entities(plan, refs, errors)
      plan.entities.each do |entity|
        model_class = model_class_for(entity.model)

        unless model_class
          errors << { code: "unknown_model", ref: entity.ref, model: entity.model }
          next
        end

        validate_count(entity, errors)
        validate_attributes(entity, model_class, errors)
        validate_belongs_to(entity, model_class, refs, errors)
      end
    end

    def validate_count(entity, errors)
      return if entity.count.positive?

      errors << { code: "invalid_count", ref: entity.ref, model: entity.model, count: entity.count }
    end

    def validate_attributes(entity, model_class, errors)
      known_attributes = model_class.attribute_names.to_set

      entity.attributes.each_key do |attribute_name|
        next if known_attributes.include?(attribute_name)

        errors << {
          code: "unknown_attribute",
          ref: entity.ref,
          model: entity.model,
          attribute: attribute_name
        }
      end
    end

    def validate_belongs_to(entity, model_class, refs, errors)
      entity.belongs_to.each do |association_name, target_ref|
        association = model_class.reflect_on_association(association_name.to_sym)

        unless association&.belongs_to?
          errors << {
            code: "unknown_belongs_to",
            ref: entity.ref,
            model: entity.model,
            association: association_name
          }
          next
        end

        next if refs.include?(target_ref.to_s)

        errors << {
          code: "unknown_ref",
          ref: entity.ref,
          model: entity.model,
          association: association_name,
          target_ref: target_ref.to_s
        }
      end
    end

    def validate_dependency_order(plan, errors)
      available_refs = Set.new

      plan.entities.each do |entity|
        entity.belongs_to.each do |association_name, target_ref|
          next if available_refs.include?(target_ref.to_s)

          errors << {
            code: "ref_not_available",
            ref: entity.ref,
            model: entity.model,
            association: association_name,
            target_ref: target_ref.to_s
          }
        end

        available_refs.add(entity.ref)
      end
    end

    def model_class_for(model_name)
      model_name.to_s.safe_constantize
    end
  end
end
