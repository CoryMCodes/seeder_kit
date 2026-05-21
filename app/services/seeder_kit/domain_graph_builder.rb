require "set"

module SeederKit
  class DomainGraphBuilder
    class DependencyCycleError < StandardError; end

    def call(schema)
      models = schema.fetch(:models)
      models_by_name = models.to_h { |model| [ model.fetch(:name), model ] }
      dependencies_by_name = dependencies_by_name(models, models_by_name)
      dependents_by_name = dependents_by_name(models_by_name.keys, dependencies_by_name)

      {
        models: graph_models(models, dependencies_by_name, dependents_by_name),
        creation_order: creation_order(models_by_name.keys, dependencies_by_name)
      }
    end

    private

    def dependencies_by_name(models, models_by_name)
      known_model_names = models_by_name.keys.to_set

      models.to_h do |model|
        [
          model.fetch(:name),
          dependencies_for(model, known_model_names).sort
        ]
      end
    end

    def dependencies_for(model, known_model_names)
      model.fetch(:associations, []).filter_map do |association|
        next unless association.fetch(:macro) == :belongs_to
        next if association.fetch(:polymorphic, false)

        class_name = association.fetch(:class_name)
        class_name if known_model_names.include?(class_name)
      end.uniq
    end

    def dependents_by_name(model_names, dependencies_by_name)
      dependents = model_names.to_h { |model_name| [ model_name, [] ] }

      dependencies_by_name.each do |model_name, dependencies|
        dependencies.each do |dependency_name|
          dependents.fetch(dependency_name) << model_name
        end
      end

      dependents.transform_values(&:sort)
    end

    def graph_models(models, dependencies_by_name, dependents_by_name)
      models.sort_by { |model| model.fetch(:name) }.map do |model|
        name = model.fetch(:name)

        {
          name: name,
          table_name: model.fetch(:table_name),
          dependencies: dependencies_by_name.fetch(name),
          dependents: dependents_by_name.fetch(name)
        }
      end
    end

    def creation_order(model_names, dependencies_by_name)
      permanent_marks = Set.new
      temporary_marks = Set.new
      ordered_names = []

      model_names.sort.each do |model_name|
        visit(model_name, dependencies_by_name, permanent_marks, temporary_marks, ordered_names, [])
      end

      ordered_names
    end

    def visit(model_name, dependencies_by_name, permanent_marks, temporary_marks, ordered_names, stack)
      return if permanent_marks.include?(model_name)

      if temporary_marks.include?(model_name)
        cycle = (stack + [ model_name ]).drop_while { |name| name != model_name }
        raise DependencyCycleError, "Cannot build domain graph because these models depend on each other: #{cycle.join(' -> ')}"
      end

      temporary_marks.add(model_name)

      dependencies_by_name.fetch(model_name).sort.each do |dependency_name|
        visit(dependency_name, dependencies_by_name, permanent_marks, temporary_marks, ordered_names, stack + [ model_name ])
      end

      temporary_marks.delete(model_name)
      permanent_marks.add(model_name)
      ordered_names << model_name
    end
  end
end
