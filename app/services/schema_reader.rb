module SeederKit
  class SchemaReader
    def initialize(ignore_prefixes: [ "Active", "Action", "SeederKit" ])
      @ignore_prefixes = ignore_prefixes
    end

    def call
      eager_load!

    ActiveRecord::Base.descendants.select { |model| valid_model?(model) }.map do |model|
      summarize(model)
      end
    end

    private
    def eager_load
    Rails.application.eager_load!
    end

    def valid_model?(model)
      model.table_exists? &&
      !model.abstract_class? &&
      @ignore_prefixes.none? { |prefix| model.name.start_with?(prefix) }
    end

    def summarize(model)
      {
          name: model.name,
        table_name: model.table_name,
        columns: model.columns.map { |col| { name: col.name, type: col.type } },
        associations: model.reflect_on_all_associations.map do |assoc|
        {
          name: assoc.name,
          macro: assoc.macro,
          class_name: assoc.class_name
        }
      end
      }
    end
  end
end
