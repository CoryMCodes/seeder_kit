require "set"

module SeederKit
  class SeedPlanBuilder
    class DependencyCycleError < StandardError; end

    def call(parsed_schema)
      tables = parsed_schema.fetch(:tables).map { |table| table.deep_dup }
      tables_by_name = tables.index_by { |table| table.fetch(:name) }
      ordered_names = dependency_order(tables_by_name)

      ordered_tables = ordered_names.map do |table_name|
        table = tables_by_name.fetch(table_name)
        table.merge(variable_name: variable_name_for(table.fetch(:name)))
      end

      { tables: ordered_tables }
    end

    private

    def dependency_order(tables_by_name)
      permanent_marks = Set.new
      temporary_marks = Set.new
      ordered_names = []

      tables_by_name.keys.sort.each do |table_name|
        visit(table_name, tables_by_name, permanent_marks, temporary_marks, ordered_names, [])
      end

      ordered_names
    end

    def visit(table_name, tables_by_name, permanent_marks, temporary_marks, ordered_names, stack)
      return if permanent_marks.include?(table_name)

      if temporary_marks.include?(table_name)
        cycle = (stack + [ table_name ]).drop_while { |name| name != table_name }
        raise DependencyCycleError, "Cannot generate seeds because these tables depend on each other: #{cycle.join(' -> ')}"
      end

      temporary_marks.add(table_name)

      dependencies_for(tables_by_name.fetch(table_name)).sort.each do |dependency_name|
        visit(dependency_name, tables_by_name, permanent_marks, temporary_marks, ordered_names, stack + [ table_name ])
      end

      temporary_marks.delete(table_name)
      permanent_marks.add(table_name)
      ordered_names << table_name
    end

    def dependencies_for(table)
      table.fetch(:columns).filter_map { |column| column[:foreign_table] }.uniq
    end

    def variable_name_for(table_name)
      table_name.singularize.underscore
    end
  end
end
