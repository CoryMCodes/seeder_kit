module SeederKit
  class ScenarioEntity
    DEFAULT_COUNT = 1

    attr_reader :ref, :model, :count, :attributes, :belongs_to

    def initialize(ref:, model:, count: DEFAULT_COUNT, attributes: {}, belongs_to: {})
      @ref = ref.to_s.strip
      @model = model.to_s.strip
      @count = count.to_i
      @attributes = normalize_hash(attributes)
      @belongs_to = normalize_hash(belongs_to)
    end

    private

    def normalize_hash(value)
      value.to_h.transform_keys(&:to_s)
    end
  end
end
