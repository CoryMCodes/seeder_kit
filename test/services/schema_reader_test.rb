require "test_helper"

module SeederKit
  class SchemaReaderTest < ActiveSupport::TestCase
    test "returns normalized model metadata" do
      schema = SchemaReader.new.call

      assert_kind_of Hash, schema
      assert_kind_of Array, schema.fetch(:models)

      post_schema = find_model(schema, "Post")

      assert_equal "Post", post_schema.fetch(:name)
      assert_equal "posts", post_schema.fetch(:table_name)
      assert_equal "id", post_schema.fetch(:primary_key)
      assert_includes post_schema.fetch(:attributes).map { |attribute| attribute.fetch(:name) }, "title"
      assert_includes post_schema.fetch(:attributes).map { |attribute| attribute.fetch(:name) }, "status"
    end

    test "extracts attribute details" do
      schema = SchemaReader.new.call
      post_schema = find_model(schema, "Post")
      title = find_attribute(post_schema, "title")
      status = find_attribute(post_schema, "status")

      assert_equal :string, title.fetch(:type)
      assert_nil title.fetch(:default)
      assert_equal false, status.fetch(:null)
      assert_equal "0", status.fetch(:default)
    end

    test "extracts associations with dependency metadata" do
      schema = SchemaReader.new.call
      post_schema = find_model(schema, "Post")
      user = find_association(post_schema, :user)
      comments = find_association(post_schema, :comments)

      assert_equal :belongs_to, user.fetch(:macro)
      assert_equal "User", user.fetch(:class_name)
      assert_equal "user_id", user.fetch(:foreign_key)
      assert_equal true, user.fetch(:required)

      assert_equal :has_many, comments.fetch(:macro)
      assert_equal "Comment", comments.fetch(:class_name)
      assert_equal "post_id", comments.fetch(:foreign_key)
      assert_equal false, comments.fetch(:required)
    end

    test "extracts enums" do
      schema = SchemaReader.new.call
      post_schema = find_model(schema, "Post")
      status = post_schema.fetch(:enums).find { |enum| enum.fetch(:name) == "status" }

      assert_equal({ "draft" => 0, "published" => 1, "archived" => 2 }, status.fetch(:values))
    end

    test "extracts validations" do
      schema = SchemaReader.new.call
      user_schema = find_model(schema, "User")
      post_schema = find_model(schema, "Post")

      user_email_validation = find_validation(user_schema, "email", :presence)
      post_title_validation = find_validation(post_schema, "title", :presence)

      assert_equal true, user_email_validation.fetch(:options).empty?
      assert_equal true, post_title_validation.fetch(:options).empty?
    end

    test "excludes SeederKit engine models" do
      schema = SchemaReader.new.call

      refute_includes schema.fetch(:models).map { |model| model.fetch(:name) }, "SeederKit::Scenario"
    end

    private

    def find_model(schema, name)
      schema.fetch(:models).find { |model| model.fetch(:name) == name } || flunk("Expected #{name} schema")
    end

    def find_attribute(model_schema, name)
      model_schema.fetch(:attributes).find { |attribute| attribute.fetch(:name) == name } ||
        flunk("Expected #{model_schema.fetch(:name)}.#{name} attribute")
    end

    def find_association(model_schema, name)
      model_schema.fetch(:associations).find { |association| association.fetch(:name) == name } ||
        flunk("Expected #{model_schema.fetch(:name)}.#{name} association")
    end

    def find_validation(model_schema, attribute, kind)
      model_schema.fetch(:validations).find do |validation|
        validation.fetch(:attribute) == attribute && validation.fetch(:kind) == kind
      end || flunk("Expected #{model_schema.fetch(:name)}.#{attribute} #{kind} validation")
    end
  end
end
