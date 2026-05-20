# Schema Reader

## Problem

SeederKit started as a Rails seed generator with a manual UI for selecting models and generating fake data. That direction was useful, but it made the project feel like a CRUD/configuration utility.

The stronger direction is natural-language scenario generation for Rails applications. In that architecture, the SchemaReader becomes the context layer for deterministic orchestration. It needs to describe the host application's domain accurately enough for later planning, validation, execution ordering, and eventually AI prompt construction.

The important constraint is that AI should not write arbitrary Ruby. AI should produce a structured plan. SeederKit should validate and execute that plan deterministically.

## Decision

Build SchemaReader as the first Phase 1 service in the schema intelligence layer.

SchemaReader should inspect loaded Active Record models and return normalized metadata for:

- model name and table name
- primary key
- attributes/columns
- associations
- enums
- validations

This output should be stable and boring on purpose. Later services such as DomainGraphBuilder, ScenarioValidator, ScenarioPromptBuilder, and ExecutionPlanner should consume this normalized structure instead of reaching back into Active Record reflection directly.

## Tradeoffs

Returning hashes is faster to implement and easy to serialize, but it can become hard to maintain if every downstream service reaches into nested hash keys casually.

Using small value objects would improve internal contracts, but it adds structure before the shape of the metadata is proven. For the first pass, normalized hashes are acceptable as long as tests lock down the contract and the service keeps extraction methods small.

Callbacks are intentionally out of the first pass. Rails callbacks are inspectable, but they are noisy and hard to summarize usefully. They are better treated later as execution risk metadata.

Scopes are also out of the first pass unless a concrete downstream use appears. Validations, enums, and associations give much more immediate leverage for scenario validation.

## Implementation Notes

Current file:

- `app/services/seeder_kit/schema_reader.rb`

Known issues in the old implementation:

- `call` invokes `eager_load!`, but the private method is named `eager_load`.
- output includes only columns and associations
- columns only expose name/type
- associations miss foreign keys, options, and requirement information
- enums and validations are not extracted
- filtering is prefix-based only and should continue excluding engine/internal models

Expected first-pass output:

```ruby
{
  models: [
    {
      name: "Post",
      table_name: "posts",
      primary_key: "id",
      attributes: [
        {
          name: "title",
          type: :string,
          sql_type: "varchar",
          null: true,
          default: nil
        }
      ],
      associations: [
        {
          name: :user,
          macro: :belongs_to,
          class_name: "User",
          foreign_key: "user_id",
          required: true
        }
      ],
      enums: [],
      validations: []
    }
  ]
}
```

## Bugs / Surprises

The dummy Rails app was too thin to prove schema intelligence at first. `User`, `Post`, and `Comment` only exercised basic columns and `belongs_to` associations. The first SchemaReader test pass made those models slightly richer with `has_many`, validations, and an enum so the service is tested against real Rails reflection features.

## Possible Devlog Angle

The interesting story is the architectural boundary: AI is useful for planning, but reliability comes from deterministic Rails introspection, validation, and execution. SchemaReader is the first piece of that reliability layer.

## Safe To Publish?

- Remove private repo paths if publishing.
- Generalize any future app-specific domain examples.
- Do not include credentials, private schema data, or customer-like records.
