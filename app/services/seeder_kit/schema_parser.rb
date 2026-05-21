module SeederKit
  class SchemaParser
    class ParseError < StandardError; end

    SUPPORTED_COLUMN_TYPES = %w[
      string text integer bigint float decimal boolean date datetime json jsonb uuid
    ].freeze

    INTERNAL_TABLE_PATTERNS = [
      /\Aschema_migrations\z/,
      /\Aar_internal_metadata\z/,
      /\Aactive_storage_/,
      /\Aaction_text_/,
      /\Aaction_mailbox_/,
      /\Aseeder_kit_/
    ].freeze

    IGNORED_COLUMN_NAMES = %w[id created_at updated_at].freeze

    def initialize(ignored_table_patterns: INTERNAL_TABLE_PATTERNS)
      @ignored_table_patterns = ignored_table_patterns
    end

    def call(schema_text)
      raise ParseError, "Paste a Rails schema.rb file to generate seeds." if schema_text.to_s.strip.empty?

      tables_by_name = {}
      foreign_keys = []
      current_table = nil

      schema_text.each_line do |line|
        if (table_name = create_table_name(line))
          current_table = build_table(table_name)
          tables_by_name[table_name] = current_table if current_table
          next
        end

        if current_table && end_block?(line)
          current_table = nil
          next
        end

        if current_table && (column = parse_column(line))
          current_table.fetch(:columns) << column unless ignored_column?(column.fetch(:name))
          next
        end

        if (foreign_key = parse_foreign_key(line))
          foreign_keys << foreign_key
        end
      end

      raise ParseError, "No supported application tables were found in the pasted schema." if tables_by_name.empty?

      apply_explicit_foreign_keys(tables_by_name, foreign_keys)
      infer_obvious_foreign_keys(tables_by_name)

      { tables: tables_by_name.values.sort_by { |table| table.fetch(:name) } }
    end

    private

    attr_reader :ignored_table_patterns

    def build_table(table_name)
      return if ignored_table?(table_name)

      {
        name: table_name,
        model_name: table_name.classify,
        columns: []
      }
    end

    def create_table_name(line)
      line.match(/^\s*create_table\s+["']([^"']+)["']/)&.[](1)
    end

    def end_block?(line)
      line.match?(/^\s*end\s*$/)
    end

    def parse_column(line)
      match = line.match(/^\s*t\.(\w+)\s+["']([^"']+)["'](.*)$/)
      return unless match

      column_type = match[1]
      return unless SUPPORTED_COLUMN_TYPES.include?(column_type)

      options = match[3].to_s

      {
        name: match[2],
        type: column_type.to_sym,
        null: parse_null_option(options),
        default: parse_default_option(options),
        default_provided: default_option?(options)
      }
    end

    def parse_foreign_key(line)
      match = line.match(/^\s*add_foreign_key\s+["']([^"']+)["']\s*,\s*["']([^"']+)["'](.*)$/)
      return unless match

      {
        from_table: match[1],
        to_table: match[2],
        column: parse_string_option(match[3].to_s, "column")
      }
    end

    def parse_null_option(options)
      match = options.match(/(?:^|,\s*)null:\s*(true|false)/)
      return true unless match

      match[1] == "true"
    end

    def parse_default_option(options)
      match = options.match(/(?:^|,\s*)default:\s*("[^"]*"|'[^']*'|[^,\s]+)/)
      return unless match

      raw_value = match[1]
      case raw_value
      when "true"
        true
      when "false"
        false
      when "nil"
        nil
      when /\A["'].*["']\z/
        raw_value[1...-1]
      when /\A-?\d+\z/
        raw_value.to_i
      when /\A-?\d+\.\d+\z/
        raw_value.to_f
      else
        raw_value
      end
    end

    def default_option?(options)
      options.match?(/(?:^|,\s*)default:/)
    end

    def parse_string_option(options, option_name)
      options.match(/(?:^|,\s*)#{Regexp.escape(option_name)}:\s*["']([^"']+)["']/)&.[](1)
    end

    def apply_explicit_foreign_keys(tables_by_name, foreign_keys)
      foreign_keys.each do |foreign_key|
        child_table = tables_by_name[foreign_key.fetch(:from_table)]
        parent_table = tables_by_name[foreign_key.fetch(:to_table)]
        next unless child_table && parent_table

        column_name = foreign_key[:column] || "#{parent_table.fetch(:name).singularize}_id"
        mark_foreign_key(child_table, column_name, parent_table.fetch(:name))
      end
    end

    def infer_obvious_foreign_keys(tables_by_name)
      tables_by_name.each_value do |table|
        table.fetch(:columns).each do |column|
          next unless column.fetch(:name).end_with?("_id")
          next if column[:foreign_table]

          candidate_table = column.fetch(:name).delete_suffix("_id").pluralize
          mark_foreign_key(table, column.fetch(:name), candidate_table) if tables_by_name.key?(candidate_table)
        end
      end
    end

    def mark_foreign_key(table, column_name, foreign_table)
      column = table.fetch(:columns).find { |candidate| candidate.fetch(:name) == column_name }
      column[:foreign_table] = foreign_table if column
    end

    def ignored_table?(table_name)
      ignored_table_patterns.any? { |pattern| table_name.match?(pattern) }
    end

    def ignored_column?(column_name)
      IGNORED_COLUMN_NAMES.include?(column_name)
    end
  end
end
