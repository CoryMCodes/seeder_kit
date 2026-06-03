---
project_name: 'seeder_kit'
user_name: 'Cory'
date: '2026-06-02'
sections_completed: ['technology_stack', 'language_specific_rules', 'framework_specific_rules', 'testing_rules', 'code_quality_style_rules', 'development_workflow_rules', 'critical_dont_miss_rules']
existing_patterns_found: 12
status: 'complete'
rule_count: 54
optimized_for_llm: true
---

# Project Context for AI Agents

_This file contains critical rules and patterns that AI agents must follow when implementing code in this project. Focus on unobvious details that agents might otherwise miss._

---

## Technology Stack & Versions

### Rails Engine
- SeederKit gem: `0.1.0`
- Ruby: `3.4.9`
- Rails: `8.0.2`
- SQLite: `2.6.0`
- Minitest: `5.27.0`
- Bundler: `2.6.8`
- RuboCop Rails Omakase: `1.1.0`

### Standalone Web Tool
- Vite: `7.3.3`
- TypeScript: `5.9.3`
- Node type definitions: `25.9.1`
- `gh-pages`: `6.3.0`

### Version Constraints
- Treat `.tool-versions` as the canonical Ruby version and keep GitHub Actions aligned with it.
- Rails engine dependency permits Rails `>= 8.0.2`.
- The web tool uses strict TypeScript and ES modules.

## Critical Implementation Rules

### Language-Specific Rules

#### Ruby
- Normalize known external keys explicitly. Scenario entities expose string keys for `attributes` and `belongs_to`; registry definitions use symbol keys. Do not indiscriminately symbolize untrusted input.
- Treat registry definitions and caller-owned input as immutable. Duplicate mutable structures before enrichment or reordering.
- Produce deterministic externally visible output. For dependency graphs, use topological ordering with deterministic tie-breaking.
- Return structured validation errors with stable string codes and relevant metadata.

#### TypeScript
- Preserve strict TypeScript compilation and ES module syntax.
- Treat pasted schemas as untrusted text. Parse and validate at the boundary before generation.
- Keep transformations side-effect free and output deterministic.
- In `NodeNext`-compiled test code, use `.js` extensions for relative imports.

### Framework-Specific Rules

#### Rails Engine
- Keep core behavior Rails-native, namespaced, UI-independent, and callable outside controllers.
- Preserve responsibility boundaries:
  - Pasted schema flow: parse -> plan -> generate
  - Live introspection flow: read schema -> build domain graph
  - Scenario flow: plan -> validate -> execute
- Keep parsing, normalization, graph construction, planning, and seed-file generation side-effect free. Database writes belong only in execution services.
- Build dependency graphs only from known, non-polymorphic `belongs_to` associations until broader support is deliberately added.
- Exclude Rails internals and SeederKit engine models from host-application schema discovery.
- Avoid assumptions about host-app controllers, views, frontend tooling, or eager model loading.

#### Standalone Vite Web Tool
- Keep the public web tool fully client-side. Pasted schemas must not leave the browser.
- Treat the web tool as a zero-setup utility, not as the driver of Rails engine architecture.
- Keep shared user-visible behavior aligned with the Rails MVP: parsing, ignored tables, dependency ordering, generated values, and validation outcomes.
- Do not require runtime code sharing between Ruby and TypeScript. Prefer behavior-level tests when alignment needs enforcement.

### Testing Rules

- Put Rails service tests in `test/services/*_test.rb` and mounted-engine request coverage in `test/integration/*_test.rb`.
- Use the dummy Rails app for host-application behavior. Keep models, schema, and fixtures representative where associations, enums, validations, or constraints affect the behavior under test.
- Add a focused regression test for every bug fix.
- For graph, parser, or planner changes, cover malformed input and assert stable output ordering for identical input.
- For scenario execution changes, assert validation occurs before writes and failures leave no partial records after transaction rollback.
- For schema discovery changes, assert inclusion of eligible host-app models and exclusion of Rails internals and SeederKit engine models.
- When changed behavior exists in both runtimes, add equivalent Ruby and TypeScript behavior-level coverage.

### Code Quality & Style Rules

- Follow `rubocop-rails-omakase`; do not add a competing Ruby style system.
- Keep engine-owned Ruby constants under `SeederKit`. Follow Zeitwerk naming: file paths must mirror constants. Host-installed generator output, migrations, and templates are explicit exceptions.
- Use focused services under `app/services/seeder_kit` for multi-step workflows or orchestration.
- Use hashes at serialization and integration boundaries; introduce value objects when shape or invariants justify them.
- Keep engine boundaries explicit. Do not rely on host-app models, routes, or configuration unless the assumption is documented in relevant public or generator documentation.
- Keep generated output deterministic: use stable ordering and avoid environment-dependent output unless explicitly part of the format.
- Use `camelCase` for TypeScript identifiers and `PascalCase` for types and classes. Preserve external, serialized, Rails-facing, and compatibility-bound key names.
- Keep comments sparse; explain only non-obvious constraints, invariants, deliberate trade-offs, or deferred decisions.
- Treat documented public APIs, seed formats, and generated output as compatibility surfaces. Record intentional breaking changes in release notes or a changelog.
- Add dependencies only when Rails, Ruby, and existing project tooling are insufficient.

### Development Workflow Rules

- Treat `.tool-versions` as the canonical Ruby version. Keep GitHub Actions aligned with it.
- Read `docs/architecture-plan.md` before architectural feature work. Update it only when implementation changes a checkpoint or architectural boundary.
- Keep focused changes scoped. Avoid unrelated refactors and metadata churn.
- Before considering Rails implementation changes complete, run:
  - `mise exec -- bin/rails test`
  - `mise exec -- bin/rubocop`
- Before considering standalone web implementation changes complete, run from `apps/web`:
  - `npm test`
  - `npm run build`
- When shared behavior changes, verify both Rails and standalone web surfaces.
- When dependency manifests change, install dependencies with the relevant package manager before running affected checks.
- Documentation-only changes do not require code verification unless they modify executable examples or commands.
- Follow the documented standalone web deployment procedure. Before publishing, verify the production build contains the expected `CNAME`.

### Critical Don't-Miss Rules

- Never evaluate or load Ruby derived from pasted schemas, scenario files, user input, or AI output. Do not use `eval`, `class_eval`, ERB evaluation, or unsafe deserialization for untrusted input.
- Treat imported and future AI-produced payloads as untrusted structured data. Resolve only validated models, attributes, associations, types, limits, and references.
- Keep parsing, normalization, discovery, graph building, preview, planning, validation, and seed-file generation free of SeederKit-owned database writes.
- Keep execution explicit and transaction-wrapped. Test rollback behavior for validation errors, callback failures, and mid-run exceptions.
- Preserve explicit scenario order until an inspectable execution planner exists. Reject missing and forward `belongs_to` references; never reorder silently.
- Treat polymorphic associations, HABTM, STI, nested attributes, and other unsupported association shapes as unsupported until implementation and tests explicitly add them.
- Exclude Rails framework tables and SeederKit-owned tables from pasted-schema generation and live discovery by default. Keep Ruby and TypeScript exclusion behavior aligned when it changes.
- Keep pasted schemas browser-local in the public web tool. Do not transmit schema content through APIs, analytics, logs, telemetry, or crash reporting.
- Keep Rails and TypeScript implementations independently maintainable. Align overlapping observable behavior through behavior-level tests; shared runtime code is optional.
- Keep core engine contracts UI-independent, including validation, preview, planning, and execution.

---

## Usage Guidelines

### For AI Agents
- Read this file before implementing code.
- Follow every rule unless the user explicitly changes the project direction.
- Prefer the more restrictive interpretation when a boundary is unclear.
- Update this file when a durable project pattern changes.

### For Humans
- Keep this file lean and focused on unobvious agent needs.
- Update it when the technology stack or architecture changes.
- Review periodically and remove stale rules.

Last Updated: 2026-06-02
