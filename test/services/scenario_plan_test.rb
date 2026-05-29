require "test_helper"

module SeederKit
  class ScenarioPlanTest < ActiveSupport::TestCase
    test "normalizes string and symbol keys into scenario entities" do
      plan = ScenarioPlan.build(
        "entities" => [
          {
            ref: :post,
            "model" => :Post,
            count: "2",
            attributes: { title: "Hello" },
            "belongs_to" => { user: :user }
          }
        ]
      )

      entity = plan.entities.first

      assert_equal "post", entity.ref
      assert_equal "Post", entity.model
      assert_equal 2, entity.count
      assert_equal({ "title" => "Hello" }, entity.attributes)
      assert_equal({ "user" => :user }, entity.belongs_to)
    end

    test "defaults count and optional hashes" do
      plan = ScenarioPlan.build(entities: [ { ref: "user", model: "User" } ])
      entity = plan.entities.first

      assert_equal 1, entity.count
      assert_equal({}, entity.attributes)
      assert_equal({}, entity.belongs_to)
    end
  end
end
