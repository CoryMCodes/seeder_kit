module SeederKit
  class SchemaReader
    DEFAULT_IGNORED_MODEL_PREFIXES = [ "Active", "Action", "SeederKit" ].freeze

    def initialize(ignored_model_prefixes: DEFAULT_IGNORED_MODEL_PREFIXES)
      @ignored_model_prefixes = ignored_model_prefixes
    end

    def call
      eager_load!

      {
        models: application_models.map { |model| summarize_model(model) }.sort_by { |model| model.fetch(:name) }
      }
    end

    private

    attr_reader :ignored_model_prefixes

    def eager_load!
      Rails.application.eager_load!
    end

    def application_models
      ActiveRecord::Base.descendants.select { |model| application_model?(model) }
    end

    def application_model?(model)
      model.name.present? &&
        model.table_exists? &&
        !model.abstract_class? &&
        ignored_model_prefixes.none? { |prefix| model.name.start_with?(prefix) }
    rescue ActiveRecord::StatementInvalid
      false
    end

    def summarize_model(model)
      {
        name: model.name,
        table_name: model.table_name,
        primary_key: model.primary_key,
        attributes: summarize_attributes(model),
        associations: summarize_associations(model),
        enums: summarize_enums(model),
        validations: summarize_validations(model)
      }
    end

    def summarize_attributes(model)
      model.columns.map do |column|
        {
          name: column.name,
          type: column.type,
          sql_type: column.sql_type,
          null: column.null,
          default: column.default
        }
      end
    end

    def summarize_associations(model)
      model.reflect_on_all_associations.map do |association|
        {
          name: association.name,
          macro: association.macro,
          class_name: association.class_name,
          foreign_key: association.foreign_key,
          required: required_association?(model, association),
          polymorphic: association.polymorphic?
        }
      end
    end

    def required_association?(model, association)
      return false unless association.macro == :belongs_to
      return false if association.options[:optional]

      foreign_key_column = model.columns_hash[association.foreign_key.to_s]
      foreign_key_column ? !foreign_key_column.null : false
    end

    def summarize_enums(model)
      model.defined_enums.map do |name, values|
        {
          name: name,
          values: values.to_h
        }
      end.sort_by { |enum| enum.fetch(:name) }
    end

    def summarize_validations(model)
      model.validators.flat_map do |validator|
        validator.attributes.map do |attribute|
          {
            attribute: attribute.to_s,
            kind: validator.kind,
            options: normalize_options(validator.options)
          }
        end
      end.sort_by { |validation| [ validation.fetch(:attribute), validation.fetch(:kind).to_s ] }
    end

    def normalize_options(options)
      options.to_h.transform_values { |value| normalize_value(value) }
    end

    def normalize_value(value)
      case value
      when Symbol, String, Numeric, TrueClass, FalseClass, NilClass
        value
      when Array
        value.map { |item| normalize_value(item) }
      when Hash
        value.transform_values { |item| normalize_value(item) }
      else
        value.inspect
      end
    end
  end
end
