require "test_helper"

module SeederKit
  class DomainGraphBuilderTest < ActiveSupport::TestCase
    test "builds a dependency graph from schema reader output" do
      schema = SchemaReader.new.call
      graph = DomainGraphBuilder.new.call(schema)

      user = find_model(graph, "User")
      post = find_model(graph, "Post")
      comment = find_model(graph, "Comment")

      assert_equal [], user.fetch(:dependencies)
      assert_equal [ "Post" ], user.fetch(:dependents)

      assert_equal [ "User" ], post.fetch(:dependencies)
      assert_equal [ "Comment" ], post.fetch(:dependents)

      assert_equal [ "Post" ], comment.fetch(:dependencies)
      assert_equal [], comment.fetch(:dependents)

      assert_equal [ "User", "Post", "Comment" ], graph.fetch(:creation_order)
    end

    test "sorts models and relationship lists deterministically" do
      schema = {
        models: [
          model_schema("Comment", "comments", associations: [ belongs_to("post", "Post") ]),
          model_schema("User", "users"),
          model_schema("Post", "posts", associations: [
            has_many("comments", "Comment"),
            belongs_to("user", "User")
          ])
        ]
      }

      graph = DomainGraphBuilder.new.call(schema)

      assert_equal [ "Comment", "Post", "User" ], graph.fetch(:models).map { |model| model.fetch(:name) }
      assert_equal [ "User", "Post", "Comment" ], graph.fetch(:creation_order)
      assert_equal [ "Comment" ], find_model(graph, "Post").fetch(:dependents)
    end

    test "ignores belongs_to associations to unknown models" do
      schema = {
        models: [
          model_schema("Post", "posts", associations: [ belongs_to("missing_user", "MissingUser") ])
        ]
      }

      graph = DomainGraphBuilder.new.call(schema)

      assert_equal [], find_model(graph, "Post").fetch(:dependencies)
      assert_equal [ "Post" ], graph.fetch(:creation_order)
    end

    test "ignores polymorphic belongs_to associations" do
      schema = {
        models: [
          model_schema("Comment", "comments", associations: [
            belongs_to("commentable", "Commentable", polymorphic: true)
          ]),
          model_schema("Post", "posts")
        ]
      }

      graph = DomainGraphBuilder.new.call(schema)

      assert_equal [], find_model(graph, "Comment").fetch(:dependencies)
    end

    test "raises a clear error for dependency cycles" do
      schema = {
        models: [
          model_schema("Account", "accounts", associations: [ belongs_to("user", "User") ]),
          model_schema("User", "users", associations: [ belongs_to("account", "Account") ])
        ]
      }

      error = assert_raises(DomainGraphBuilder::DependencyCycleError) do
        DomainGraphBuilder.new.call(schema)
      end

      assert_match "Cannot build domain graph because these models depend on each other", error.message
    end

    private

    def find_model(graph, name)
      graph.fetch(:models).find { |model| model.fetch(:name) == name } || flunk("Expected #{name} model")
    end

    def model_schema(name, table_name, associations: [])
      {
        name: name,
        table_name: table_name,
        associations: associations
      }
    end

    def belongs_to(name, class_name, polymorphic: false)
      {
        name: name,
        macro: :belongs_to,
        class_name: class_name,
        polymorphic: polymorphic
      }
    end

    def has_many(name, class_name)
      {
        name: name,
        macro: :has_many,
        class_name: class_name,
        polymorphic: false
      }
    end
  end
end
