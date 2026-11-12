# frozen_string_literal: true

module RecordStore
  class Zone
    class Config
      class TemplateContext
        class << self
          def build(record:, current_records:)
            new(record: record, current_records: current_records)
          end
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
        class InvalidTemplateFilename < ArgumentError; end

        class << self
          def from_file(filename:)
            filepath = template_filepath_for(filename: filename)
            template_file = File.read(filepath)

            template_file_yaml = YAML.safe_load(template_file, permitted_classes: [Regexp]).deep_symbolize_keys
            filters_for_records_to_template = template_file_yaml[:each_record]
            filters_for_records_to_exclude = template_file_yaml[:except_record] || []

            new(
              template: ERB.new(template_file),
              filters_for_records_to_template: filters_for_records_to_template,
              filters_for_records_to_exclude: filters_for_records_to_exclude,
            )
          end

          private

          # Templates are rendered as ERB, so only files directly inside the
          # configured templates directory may be loaded. Zone definitions name a
          # template by its plain file name; anything that could resolve elsewhere
          # (path separators, `.`/`..`, or a symlink out of the directory) is rejected.
          def template_filepath_for(filename:)
            name = filename.to_s
            base = Pathname.new(RecordStore.implicit_records_templates_path).realpath

            if name.empty? || name == '.' || name == '..' || name != File.basename(name)
              raise InvalidTemplateFilename,
                "implicit record template #{filename.inspect} must be a plain file name in #{base}"
            end

            path = base.join(name).realpath
            unless path.dirname == base
              raise InvalidTemplateFilename,
                "implicit record template #{filename.inspect} resolves outside #{base}"
            end

            path.to_s
          end
        end

        def initialize(template:, filters_for_records_to_template:, filters_for_records_to_exclude:)
          @template = template
          @filters_for_records_to_template = filters_for_records_to_template
          @filters_for_records_to_exclude = filters_for_records_to_exclude
        end

        def generate_records_to_inject(current_records:)
          # Every [type, fqdn] pair currently in the zone, including what has been injected so far. Conflict filters
          # that only name a type and an fqdn are answered from this set instead of scanning every record.
          present = Set.new(current_records.map { |record| [record.type, record.fqdn] })

          current_records
            .select { |record| should_template?(record: record) }
            .map { |record| template_record_for(record: record, current_records: current_records) }
            .each_with_object([]) do |template_records, records_to_inject|
              next unless should_inject?(
                template_records: template_records,
                current_records: current_records,
                records_to_inject: records_to_inject,
                present: present,
              )

              new_records = template_records.fetch(:injected_records, []).map do |r_yml|
                Record.build_from_yaml_definition(r_yml)
              end
              new_records.each { |record| present << [record.type, record.fqdn] }
              records_to_inject.push(*new_records)
            end
        end

        private

        attr_reader :template, :filters_for_records_to_template, :filters_for_records_to_exclude

        def should_inject?(template_records:, current_records:, records_to_inject:, present:)
          conflict_with = template_records[:conflict_with] || []

          if conflict_with.all? { |filter| type_and_fqdn_filter?(filter) }
            conflict_with.none? { |filter| present.include?([filter[:type], filter[:fqdn]]) }
          else
            !conflicts_with_any?(conflict_with: conflict_with, records: current_records + records_to_inject)
          end
        end

        # The general check: any record matching any filter is a conflict. Used for filters that match on anything
        # other than an exact type and fqdn (regexps, other attributes).
        def conflicts_with_any?(conflict_with:, records:)
          records.any? do |record|
            conflict_with.any? do |filter|
              record_match?(record: record, filter: filter)
            end
          end
        end

        def type_and_fqdn_filter?(filter)
          filter.is_a?(Hash) &&
            filter.keys.sort == [:fqdn, :type] &&
            filter[:type].is_a?(String) &&
            filter[:fqdn].is_a?(String)
        end

        def should_template?(record:)
          filters_for_records_to_template.any? { |filter| record_match?(record: record, filter: filter) } &&
            filters_for_records_to_exclude.none? { |filter| record_match?(record: record, filter: filter) }
        end

        def record_match?(record:, filter:)
          filter.all? do |key, value|
            if value.is_a?(Regexp)
              value.match(record.public_send(key))
            else
              record.public_send(key) == value
            end
          end
        end

        def template_record_for(record:, current_records:)
          context = TemplateContext.build(record: record, current_records: current_records)

          YAML.safe_load(
            template.result(context.fetch_binding),
            permitted_classes: [Regexp],
          ).deep_symbolize_keys
        end
      end
    end
  end
end
