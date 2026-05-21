require "test_helper"

module SeederKit
  class SchemaParserTest < ActiveSupport::TestCase
    test "parses application tables from a Rails schema" do
      parsed_schema = SchemaParser.new.call(dummy_schema)

      table_names = parsed_schema.fetch(:tables).map { |table| table.fetch(:name) }

      assert_equal [ "comments", "posts", "users" ], table_names

      post_table = find_table(parsed_schema, "posts")
      user_id = find_column(post_table, "user_id")
      status = find_column(post_table, "status")

      assert_equal "Post", post_table.fetch(:model_name)
      assert_equal :integer, user_id.fetch(:type)
      assert_equal false, user_id.fetch(:null)
      assert_equal "users", user_id.fetch(:foreign_table)
      assert_equal 0, status.fetch(:default)
      assert_equal true, status.fetch(:default_provided)
    end

    test "parses a compact inline schema without evaluating it" do
      schema = <<~RUBY
        ActiveRecord::Schema[8.0].define do
          create_table "projects", force: :cascade do |t|
            t.string "name", null: false
            t.uuid "public_id"
            t.datetime "created_at", null: false
          end

          create_table "tasks", force: :cascade do |t|
            t.bigint "project_id", null: false
            t.boolean "done", default: false, null: false
          end

          create_table "active_storage_blobs", force: :cascade do |t|
            t.string "key"
          end

          add_foreign_key "tasks", "projects"
        end
      RUBY

      parsed_schema = SchemaParser.new.call(schema)
      project_table = find_table(parsed_schema, "projects")
      task_table = find_table(parsed_schema, "tasks")

      assert_equal [ "public_id", "name" ].sort, project_table.fetch(:columns).map { |column| column.fetch(:name) }.sort
      assert_equal "projects", find_column(task_table, "project_id").fetch(:foreign_table)
      refute parsed_schema.fetch(:tables).any? { |table| table.fetch(:name) == "active_storage_blobs" }
    end

    test "raises a clear error for blank input" do
      error = assert_raises(SchemaParser::ParseError) { SchemaParser.new.call(" ") }

      assert_equal "Paste a Rails schema.rb file to generate seeds.", error.message
    end

    private

    def dummy_schema
      File.read(Rails.root.join("db/schema.rb"))
    end

    def find_table(parsed_schema, name)
      parsed_schema.fetch(:tables).find { |table| table.fetch(:name) == name } || flunk("Expected #{name} table")
    end

    def find_column(table, name)
      table.fetch(:columns).find { |column| column.fetch(:name) == name } || flunk("Expected #{table.fetch(:name)}.#{name}")
    end
  end
end
