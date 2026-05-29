module SeederKit
  class ScenarioPlan
    attr_reader :entities

    def self.build(input)
      new(input)
    end

    def initialize(input)
      normalized_input = normalize_hash(input)

      @entities = Array(normalized_input.fetch("entities", [])).map do |entity_input|
        normalized_entity = normalize_hash(entity_input)

        ScenarioEntity.new(
          ref: normalized_entity["ref"],
          model: normalized_entity["model"],
          count: normalized_entity.fetch("count", ScenarioEntity::DEFAULT_COUNT),
          attributes: normalized_entity.fetch("attributes", {}),
          belongs_to: normalized_entity.fetch("belongs_to", {})
        )
      end
    end

    private

    def normalize_hash(value)
      value.to_h.transform_keys(&:to_s)
    end
  end
end
