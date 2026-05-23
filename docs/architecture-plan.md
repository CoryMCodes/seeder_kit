# SeederKit Architecture Plan

Last updated: 2026-05-22

## Purpose

SeederKit has two related surfaces:

- **Standalone web tool:** a zero-setup Vite app for `schema.rb -> seeds.rb`.
- **Rails engine:** an installable Rails-native system for schema-aware development data and scenario orchestration.

The Rails engine is the primary product direction. The standalone web tool is a lightweight public utility and demo surface. It should not drive engine architecture decisions.

The long-term engine direction is:

```txt
natural language or structured request
-> structured scenario plan
-> deterministic validation
-> deterministic execution
-> repeatable development state
```

AI can eventually help translate intent into a structured plan. AI should not write arbitrary Ruby. SeederKit should own schema discovery, graph construction, validation, ordering, execution, and replay.

## Current System Map

```txt
apps/web
  Vite + TypeScript static webpage
  paste schema.rb -> generate starter seeds.rb
  deploy target: GitHub Pages at seederkit.dev

Rails engine
  SchemaParser -> SeedPlanBuilder -> SeedFileGenerator
    pasted schema.rb MVP inside the mounted engine

  SchemaReader -> DomainGraphBuilder
    live Rails app introspection path for the full engine
```

The public webpage and engine do not need to share runtime code right now. They should share product behavior and vocabulary. The webpage can stay simple while the engine grows the deeper Rails-native orchestration system.

Boundary rule:

```txt
web app:
  optimize for immediate usefulness and zero setup

Rails engine:
  optimize for Rails-native introspection, deterministic orchestration, and repeatable app state
```

## Phase 0 - Public Web Tool

Goal: Provide a low-friction public utility that proves the simple input/output loop.

```txt
input: Rails schema.rb
output: starter db/seeds.rb
```

Checkpoints:

- [x] Create standalone Vite + TypeScript app in `apps/web`.
- [x] Port schema parsing, dependency ordering, and seed generation to TypeScript.
- [x] Add tests for parser/order/generator behavior.
- [x] Add simple UI with schema input, generated output, sample schema, copy action.
- [x] Configure GitHub Pages deploy with `gh-pages`.
- [x] Configure custom domain via `public/CNAME` for `seederkit.dev`.
- [ ] Deploy first public version.
- [ ] Add basic usage copy and examples.
- [ ] Collect real schemas or feedback to identify parser gaps.

Definition of done:

- `npm test` passes.
- `npm run build` passes.
- `npm run deploy` publishes the static app.
- `seederkit.dev` serves the tool over HTTPS.

## Phase 1 - Schema Intelligence Layer

Goal: Give the Rails engine a deterministic understanding of the host app.

Current services:

- `SeederKit::SchemaReader`
- `SeederKit::DomainGraphBuilder`

Checkpoints:

- [x] Load application Active Record models.
- [x] Exclude internal Rails and SeederKit engine models.
- [x] Extract model name, table name, primary key, attributes, associations, enums, and validations.
- [x] Expose raw schema metadata at `GET /models`.
- [x] Build dependency graph from non-polymorphic `belongs_to` associations.
- [x] Expose graph metadata at `GET /domain_graph`.
- [x] Compute deterministic parent-first `creation_order`.
- [x] Raise clear error for dependency cycles.
- [ ] Decide whether graph services should move from `app/services` to `lib` before CLI work.
- [ ] Add optional risk metadata for callbacks/scopes only if a downstream service needs it.

Definition of done:

- `mise exec -- bin/rails test` passes.
- Schema and graph JSON contracts are covered by tests.
- The graph is sufficient input for scenario validation and execution planning.

## Phase 2 - Structured Scenario Format

Goal: Define the internal scenario representation before adding AI.

This is the next likely engine step.

The format should describe requested records and relationships, not executable Ruby. Start with Ruby hash / JSON input rather than a Ruby DSL. Future AI planners can target the same structure directly.

Example direction:

```ruby
{
  entities: [
    {
      ref: "user_author",
      model: "User",
      count: 1,
      attributes: {
        email: "author@example.com"
      }
    },
    {
      ref: "posts",
      model: "Post",
      count: 3,
      attributes: {
        title: "Generated Post"
      },
      belongs_to: {
        user: "user_author"
      }
    }
  ]
}
```

Checkpoints:

- [ ] Add `SeederKit::ScenarioPlan`.
- [ ] Add `SeederKit::ScenarioEntity`.
- [ ] Accept input as a Ruby hash.
- [ ] Normalize string and symbol keys.
- [ ] Require stable `ref` values for entity references.
- [ ] Support `model`, `count`, `attributes`, and `belongs_to` relationship wiring.
- [ ] Support basic attribute overrides.
- [ ] Do not touch the database.
- [ ] Do not validate against Active Record yet.
- [ ] Defer `SeederKit::ScenarioRelationship` unless `belongs_to` on entities becomes insufficient.
- [ ] Add tests proving the format can describe the dummy app scenarios:
  - simple users
  - users with posts
  - users -> posts -> comments
  - invalid model as data, not validation failure yet
  - invalid attribute as data, not validation failure yet
  - missing parent dependency as data, not validation failure yet
  - enum-looking value as data, not validation failure yet

Definition of done:

- The scenario format can express "create users, posts, comments with dependencies" without Ruby code generation.
- Entity refs are stable enough for validation, planning, execution, and future AI repair loops.
- The format is stable enough for a validator and future AI planner to target.

Open design topic for this phase:

```ruby
attributes: {
  email: "author@example.com"
}
```

Static scalar values are enough for the first contract. Attribute strategies should be named before validation/execution work begins, but they do not need full implementation in the first scenario-format pass.

Likely future strategy shape:

```ruby
attributes: {
  email: { strategy: "static", value: "test@example.com" },
  created_at: { strategy: "relative_time", value: "3.days.ago" },
  status: "published"
}
```

## Phase 3 - Scenario Validation Layer

Goal: Validate scenario plans deterministically before anything executes.

Inputs:

- `SchemaReader` output
- `DomainGraphBuilder` output
- structured scenario plan

Checkpoints:

- [ ] Add `SeederKit::ScenarioValidator`.
- [ ] Validate referenced models exist.
- [ ] Validate referenced attributes exist.
- [ ] Validate counts are positive and reasonable.
- [ ] Validate required parent dependencies can be satisfied.
- [ ] Validate enum values when state/attribute support is added.
- [ ] Account for required DB columns, nullable columns, defaults, generated timestamps, Rails-managed fields, foreign keys, and model validations.
- [ ] Add or define `SeederKit::AttributeResolver` to fill missing safe values before execution.
- [ ] Return structured, machine-correctable errors instead of raw implementation exceptions.

Example validation error:

```ruby
{
  code: "unknown_attribute",
  model: "User",
  attribute: "full_name",
  suggestions: ["name", "first_name", "last_name"]
}
```

Definition of done:

- Invalid scenario plans fail before execution.
- Error messages are precise enough for a user, CLI, or future AI planner to correct the plan.
- Errors have stable codes and enough metadata for future AI retry behavior.

## Phase 4 - Execution Planning

Goal: Convert a valid scenario plan into deterministic ordered operations.

Checkpoints:

- [ ] Add `SeederKit::ExecutionPlanner`.
- [ ] Use `DomainGraphBuilder` creation order for parent-first operations.
- [ ] Resolve entity references and relationship wiring.
- [ ] Produce an operation list without touching the database.
- [ ] Add cycle/unsatisfied-dependency tests.

Example output shape:

```ruby
[
  { action: :create, model: "User", ref: "user_1", attributes: {} },
  { action: :create, model: "Post", ref: "post_1", attributes: { user: "user_1" } }
]
```

Definition of done:

- Execution planning is deterministic and side-effect free.
- Operation order can be inspected in tests and future CLI output.

## Phase 5 - Execution Engine

Goal: Execute planned operations safely.

Checkpoints:

- [ ] Add `SeederKit::ScenarioExecutor`.
- [ ] Support transaction-wrapped execution.
- [ ] Support direct `create!` mode first.
- [ ] Return created record references/results in memory.
- [ ] Add rollback behavior tests.
- [ ] Defer workflow/service-object mode until direct execution is proven.
- [ ] Defer persistent run metadata until direct execution is useful.

Definition of done:

- A valid scenario plan can create records in the dummy app.
- Failed execution rolls back cleanly.
- Execution results are inspectable.

Deferred persistence concept:

- `SeederKit::ScenarioRun`
- `SeederKit::CreatedRecord`

v1 direct execution should return in-memory refs only. Persistent run tracking comes later.

## Phase 6 - CLI Surface

Goal: Add a Rails-native command surface that reuses core services.

Checkpoints:

- [ ] Decide command entrypoint: Rails generator, rake task, executable, or Thor command.
- [ ] Add command for schema/graph inspection.
- [ ] Add command for validating a scenario file.
- [ ] Add command for planning execution without writing records.
- [ ] Add command for executing a scenario.

Definition of done:

- A developer can inspect, validate, plan, and eventually run scenarios from the terminal.
- CLI uses the same services as the engine endpoints.

## Phase 7 - AI Planning Layer

Goal: Translate natural language into the structured scenario format.

Do not start this until the scenario format, validator, planner, and basic executor exist.

Checkpoints:

- [ ] Add `SeederKit::ScenarioPromptBuilder`.
- [ ] Summarize schema and graph context without dumping everything blindly.
- [ ] Add `SeederKit::ScenarioPlanner`.
- [ ] Require structured JSON output.
- [ ] Validate all AI output through `ScenarioValidator`.
- [ ] Never execute AI-generated Ruby.

Definition of done:

- AI output is treated as an untrusted scenario plan.
- Invalid plans are rejected deterministically.
- Successful plans go through the same execution path as hand-written plans.

## Phase 8 - Scenario Memory and Replay

Goal: Save, refine, and replay useful scenarios.

Checkpoints:

- [ ] Define scenario file format.
- [ ] Support JSON or YAML scenario files.
- [ ] Add load/save behavior.
- [ ] Add replay command.
- [ ] Add versioning or metadata only when needed.

Definition of done:

- A generated or hand-written scenario can be committed, shared, and replayed.

Artifact boundary:

- Engine primary artifact: scenario JSON/YAML.
- Web primary artifact: generated `seeds.rb`.
- Ruby seed export from engine scenarios: optional later.

## Current Next Step

Recommended next implementation:

```txt
Phase 2 - Structured Scenario Format
```

Reason:

- `SchemaReader` and `DomainGraphBuilder` now provide the app context.
- The engine needs stable refs, attributes, and relationship wiring before validation, execution, CLI, or AI work can be coherent.
- This keeps AI small and deterministic orchestration large.

Recommended next implementation scope:

- `SeederKit::ScenarioPlan`
- `SeederKit::ScenarioEntity`
- Ruby hash parser/normalizer
- support for `ref`, `model`, `count`, `attributes`, and `belongs_to`
- contract tests using dummy app concepts only
- no database access
- no Active Record validation yet

## Non-Goals For Now

- No AI-generated Ruby.
- No vector database.
- No multi-agent system.
- No visual graph editor.
- No workflow execution mode until direct execution works.
- No complex UI before the service contracts are stable.
- No polymorphic association support yet.
- No HABTM support yet.
- No STI support yet.
- No complex nested attributes yet.
- No Ruby DSL until the JSON/hash contract is stable.

UI boundary:

- All core behavior must be usable without UI.
- UI should only call documented service contracts.
- Engine services should remain callable from tests, CLI, controllers, and future AI adapters.

## Resume Checklist

When picking this project back up:

1. Read this file first.
2. Check `git status --short`.
3. Run the relevant verification:
   - engine: `mise exec -- bin/rails test`
   - webpage: `cd apps/web && npm test && npm run build`
4. Continue from `Current Next Step` unless the user explicitly redirects.
