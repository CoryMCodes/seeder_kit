# Building And Releasing SeederKit

SeederKit is not published to RubyGems yet. These commands verify a candidate
artifact without publishing it.

## Build And Inspect

Run from the repository root with the Ruby version in `.tool-versions`:

```bash
mkdir -p pkg
mise exec -- gem build seeder_kit.gemspec --output pkg/seeder_kit-0.1.0.gem
mise exec -- ruby -rrubygems/package -e \
  'package = Gem::Package.new("pkg/seeder_kit-0.1.0.gem"); puts package.contents'
mise exec -- bin/rails test test/packaging/gem_artifact_test.rb
```

The packaging test builds a fresh artifact, validates public metadata, and
reports missing or unexpected contents by path.

## Install Smoke Check

Install the built artifact into an isolated gem directory and require the
engine:

```bash
tmp_dir="$(mktemp -d)"
mise exec -- gem install --local pkg/seeder_kit-0.1.0.gem \
  --install-dir "$tmp_dir" --ignore-dependencies --no-document
GEM_HOME="$tmp_dir" mise exec -- ruby -I"$tmp_dir/gems/seeder_kit-0.1.0/lib" \
  -e 'require "rails"; require "seeder_kit"; abort unless defined?(SeederKit::Engine)'
```

## Future Publication

`bundler/gem_tasks` provides the normal `rake release` workflow, but publishing
is intentionally deferred. Do not run `rake release` or `gem push` until the
release-candidate gates pass and the separate manual release workflow is ready.
