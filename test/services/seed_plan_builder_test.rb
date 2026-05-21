require "test_helper"

module SeederKit
  class SeedPlanBuilderTest < ActiveSupport::TestCase
    test "orders tables so parents are created before dependents" do
      parsed_schema = SchemaParser.new.call(File.read(Rails.root.join("db/schema.rb")))
      seed_plan = SeedPlanBuilder.new.call(parsed_schema)

      ordered_table_names = seed_plan.fetch(:tables).map { |table| table.fetch(:name) }

      assert_operator ordered_table_names.index("users"), :<, ordered_table_names.index("posts")
      assert_operator ordered_table_names.index("posts"), :<, ordered_table_names.index("comments")
    end

    test "adds deterministic variable names" do
      parsed_schema = {
        tables: [
          { name: "line_items", model_name: "LineItem", columns: [] }
        ]
      }

      seed_plan = SeedPlanBuilder.new.call(parsed_schema)

      assert_equal "line_item", seed_plan.fetch(:tables).first.fetch(:variable_name)
    end

    test "raises a clear error for dependency cycles" do
      parsed_schema = {
        tables: [
          {
            name: "accounts",
            model_name: "Account",
            columns: [ { name: "user_id", type: :integer, foreign_table: "users" } ]
          },
          {
            name: "users",
            model_name: "User",
            columns: [ { name: "account_id", type: :integer, foreign_table: "accounts" } ]
          }
        ]
      }

      error = assert_raises(SeedPlanBuilder::DependencyCycleError) { SeedPlanBuilder.new.call(parsed_schema) }

      assert_match "Cannot generate seeds because these tables depend on each other", error.message
    end
  end
end
