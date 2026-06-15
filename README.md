# SeederKit

SeederKit is a Rails engine for defining, previewing, validating, composing, and executing named development data states in Rails applications.

The current product center is the Rails-native scenario workflow:

```txt
define named scenario
-> list available scenarios in Ruby
-> preview and validate planned state
-> run in one transaction
-> share the definition with a teammate
```

SeederKit also includes a standalone client-side web utility in `apps/web` that turns pasted `schema.rb` text into a starter `db/seeds.rb` file. That utility is intentionally separate from the Rails engine workflow.

## Current Status

SeederKit is early-stage. The shipped Rails engine currently provides service-level Ruby APIs for:

- Structured scenario plans using Ruby hashes.
- Named scenario registration with typed inputs.
- Shallow scenario composition.
- Side-effect-free preview and validation.
- Transaction-wrapped execution with rollback on failure.
- Live schema reading and deterministic domain graph services.

The Rails command workflow is roadmap work, not shipped behavior yet. Commands such as `bin/rails seeder_kit:list`, `bin/rails seeder_kit:preview[NAME]`, and `bin/rails seeder_kit:run[NAME]` are planned for the next operator workflow slices.

## Compatibility

The current repository development baseline is Ruby 3.4.9 and Rails 8.0.2. SeederKit does not yet publish a verified compatibility matrix.

Rails 7 support is a desired post-first-release roadmap item, pending demonstrated demand and CI verification. Rails 8.1 and other unverified versions are not currently claimed as supported.

## Installation

SeederKit is not published to RubyGems yet. To evaluate the current pre-release
source in a compatible Rails application, add the public HTTPS Git source:

```ruby
gem "seeder_kit", git: "https://github.com/CoryMCodes/seeder_kit.git", branch: "main"
```

Then install and verify the engine boots:

```bash
bundle install
bin/rails runner 'abort unless defined?(SeederKit::Engine)'
```

Pin a commit with `ref:` when a repeatable evaluation baseline is required.
This source-install path is separate from a future published RubyGems release.

## Define A Scenario Plan

SeederKit plans are structured hashes. They describe records and relationships; they are not executable Ruby code generated from user input.

```ruby
plan = {
  entities: [
    {
      ref: "user",
      model: "User",
      attributes: {
        name: "Alice",
        email: "alice@example.com"
      }
    },
    {
      ref: "post",
      model: "Post",
      count: 2,
      attributes: {
        title: "Hello",
        body: "Test body"
      },
      belongs_to: {
        user: "user"
      }
    }
  ]
}
```

Supported entity keys today:

- `ref`: stable reference used by validation, relationships, preview, and execution results.
- `model`: Active Record model name.
- `count`: positive record count; defaults to `1`.
- `attributes`: static attribute values.
- `belongs_to`: association name to earlier entity `ref`.

## Preview A Plan

Preview validates the plan and returns an inspectable summary without writing records.

```ruby
preview = SeederKit.preview(plan)

preview.valid?
preview.total_records
preview.entities.map(&:ref)
```

Preview currently validates model names, attribute names, counts, referenced entity refs, and first-slice `belongs_to` ordering rules.

## Run A Plan

Execution uses the same validation path and creates records inside one transaction.

```ruby
result = SeederKit.run(plan)

result.records_by_ref.fetch("user")
result.records_by_ref.fetch("post")
```

If validation or Active Record creation fails, execution raises and the transaction rolls back.

## Register Named Scenarios

Named scenarios are registered with `SeederKit.scenario`. A scenario may define a static plan or a dynamic plan block that receives resolved typed inputs.

```ruby
SeederKit.scenario "Parameterized user with posts" do
  description "Creates users and related posts for local development."

  input :user_count, type: :integer, default: 1
  input :posts_per_user, type: :integer, default: 2

  plan do |inputs|
    {
      entities: [
        {
          ref: "user",
          model: "User",
          count: inputs.fetch(:user_count),
          attributes: {
            name: "Parameterized",
            email: "parameterized@example.com"
          }
        },
        {
          ref: "post",
          model: "Post",
          count: inputs.fetch(:user_count) * inputs.fetch(:posts_per_user),
          attributes: {
            title: "Parameterized post",
            body: "Test body"
          },
          belongs_to: {
            user: "user"
          }
        }
      ]
    }
  end
end
```

Use the registry API directly:

```ruby
SeederKit.scenarios
SeederKit.preview_scenario("Parameterized user with posts", user_count: 2)
SeederKit.run_scenario("Parameterized user with posts", user_count: 2, posts_per_user: 4)
```

Supported input types are `:integer`, `:string`, and `:boolean`. Unknown inputs, missing required inputs, and invalid input types fail clearly before execution.

## Compose Scenarios

SeederKit supports shallow composition of leaf scenarios:

```ruby
SeederKit.scenario "Demo content" do
  input :demo_user_count, type: :integer, default: 2

  include_scenario "Parameterized user with posts", user_count: :demo_user_count
end
```

Composition is deliberately narrow today. It preserves include order, applies parent input mappings and literal child inputs, rejects nested composition, and rejects cross-child references.

## Standalone Web Utility

The `apps/web` app is a zero-setup public utility:

```txt
paste Rails schema.rb -> generate a starter db/seeds.rb file
```

It runs fully in the browser. Pasted schemas should remain local to the browser and should not be treated as the Rails engine scenario workflow.

Run it locally with:

```bash
cd apps/web
npm install
npm test
npm run build
```

## Supported Behavior

SeederKit currently supports:

- Ruby hash scenario plans.
- Static scalar attribute values.
- Positive record counts.
- Non-polymorphic `belongs_to` relationships that point to earlier entity refs.
- Named scenario registration.
- Typed scenario inputs.
- Shallow composition of leaf scenarios.
- Preview without database writes.
- Transaction-wrapped execution with rollback on failure.
- Schema reading and dependency graph construction for host Rails apps.

## Unsupported Behavior

SeederKit does not currently support:

- Polymorphic associations.
- HABTM associations.
- STI-specific planning.
- Nested attributes.
- Nested scenario composition.
- Cross-child references in composed scenarios.
- Automatic callback orchestration.
- Orchestrating or suppressing external-service side effects.
- Arbitrary model workflow/service-object execution.
- AI-generated Ruby.
- JSON or YAML scenario files.
- Rails CLI commands for list, preview, or run.
- Production execution safeguards. This is planned before the CLI run command ships.

Callbacks and external services may still run if your Active Record models invoke them during `create!`. SeederKit does not yet infer or manage those effects.

## Roadmap

Near-term roadmap work is tracked in `_bmad-output/planning-artifacts/seederkit-usable-state-roadmap-2026-06-08.md`.

### Near-Term

- Keeping documentation and product claims truthful.
- Removing or disabling false-success UI actions.
- Making the gem buildable and release-ready.
- Refusing production execution by default.
- Adding Rails commands for scenario list, preview, and run.
- Improving preview validation for common required-value and enum failures.

### Deferred

Rails 7 support is desired after the first release, pending demonstrated demand and CI verification.

AI planning, visual scenario editing, persistent run history, JSON/YAML scenario files, and broader association support are intentionally deferred until the first Rails-native workflow is useful to external design partners.

## Project Docs

- [Docs index](docs/README.md)
- [Architecture plan](docs/architecture-plan.md)
- [Building and releasing](docs/releasing.md)
- [Product roadmap](./_bmad-output/planning-artifacts/seederkit-usable-state-roadmap-2026-06-08.md)

## Development Checks

Rails engine:

```bash
mise exec -- bin/rails test
mise exec -- bin/rubocop
```

Standalone web utility:

```bash
cd apps/web
npm test
npm run build
```

## License

MIT License
