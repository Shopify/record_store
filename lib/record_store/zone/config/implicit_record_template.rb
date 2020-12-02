# frozen_string_literal: true
module RecordStore
  class Zone
    class Config
      class TemplateContext
        def self.build(record:, current_records:)
          new(record: record, current_records: current_records)
        end

        def initialize(record:, current_records:)
          @record = record
          @current_records = current_records
        end

        def fetch_binding
          binding
        end

        private

        attr_reader :record, :current_records
      end

      class ImplicitRecordTemplate
        class << self
          def from_file(filename:)
            filepath = template_filepath_for(filename: filename)
            template_file = File.read(filepath)
            filters_for_records_to_template = YAML.load(template_file).deep_symbolize_keys[:each_record]

            new(template: ERB.new(template_file), filters_for_records_to_template: filters_for_records_to_template)
          end

          private

          def template_filepath_for(filename:)
            "#{RecordStore.implicit_records_templates_path}/#{filename}"
          end
        end

        def initialize(template:, filters_for_records_to_template:)
          @template = template
          @filters_for_records_to_template = filters_for_records_to_template
        end

        def generate_records_to_inject(current_records:)
          current_records
            .select { |record| should_template?(record: record) }
            .map { |record| template_record_for(record: record, current_records: current_records) }
            .each_with_object([]) do |template_records, records_to_inject|
              next unless should_inject?(
                template_records: template_records,
                current_records: current_records + records_to_inject
              )

              records_to_inject.push(
                *template_records.fetch(:injected_records, []).map { |r_yml| Record.build_from_yaml_definition(r_yml) }
              )
            end
        end

        private

        attr_reader :template, :filters_for_records_to_template

        def should_inject?(template_records:, current_records:)
          current_records.none? do |record|
            template_records[:conflict_with].any? do |filter|
              record_match?(record: record, filter: filter)
            end
          end
        end

        def should_template?(record:)
          filters_for_records_to_template.any? { |filter| record_match?(record: record, filter: filter) }
        end

        def record_match?(record:, filter:)
          filter.all? do |key, value|
            record.public_send(key) == value
          end
        end

        def template_record_for(record:, current_records:)
          context = TemplateContext.build(record: record, current_records: current_records)

          YAML.load(
            template.result(context.fetch_binding)
          ).deep_symbolize_keys
        end
      end
    end
  end
end
