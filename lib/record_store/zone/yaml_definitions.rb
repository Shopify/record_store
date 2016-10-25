module RecordStore
  class Zone
    module YamlDefinitions
      include Enumerable

      def all
        defined.values
      end

      def defined
        @defined ||= yaml_files
          .map { |file| load_yml_zone_definition(file) }
          .index_by { |zone| zone.name.chomp('.') }
      end

      def [](name)
        defined.fetch(name)
      end

      def each(&block)
        defined.each(&block)
      end

      def find(name)
        defined[name]
      end

      def reset
        @defined = nil
      end

      def write(name, config:, records:, format: :file)
        raise ArgumentError, "format must be :directory or :file" unless %i(file directory).include?(format)
        name = name.chomp('.')
        zone_file = "#{RecordStore.zones_path}/#{name}.yml"
        zone = { name => { config: config.to_hash } }
        records = records.map(&:to_hash).sort_by! {|r| [r.fetch(:fqdn), r.fetch(:type), r[:nsdname] || r[:address]]}

        if format == :file
          zone[name][:records] = records
          write_yml_file(zone_file, zone.deep_stringify_keys)
          remove_record_files(name)
        else
          write_yml_file(zone_file, zone.deep_stringify_keys)
          remove_record_files(name)
          write_record_files(name, records)
        end
      end

      private

      def write_yml_file(filename, data)
        lines = data.to_yaml.lines
        lines.shift if lines.first == "---\n"
        File.write(filename, lines.join)
      end

      def load_yml_zone_definition(filename)
        dir = File.dirname(filename)
        data = YAML.load_file(filename)
        raise 'more than one zone in file' if data.size > 1
        name, definition = data.first
        definition['records'] ||= []
        definition['records'] = definition['records'].map {|hash| hash.inject({}){|h,(k,v)| h[k.to_sym] = v; h}}
        Dir["#{dir}/#{name}/*__*.yml"].each do |record_file|
          definition['records'] += load_yml_record_definitions(name, record_file)
        end
        Zone.new(name: name, records: definition['records'], config: definition['config'])
      end

      def load_yml_record_definitions(name, record_file)
        type, domain = File.basename(record_file, '.yml').split('__')
        Array.wrap(YAML.load_file(record_file)).map do |record_definition|
          record_definition.merge('fqdn' => "#{domain}.#{name}", 'type' => type)
        end.map do |hash|
          hash.inject({}){|h,(k,v)| h[k.to_sym] = v; h}
        end
      end

      def remove_record_files(name)
        dir = "#{RecordStore.zones_path}/#{name}"
        File.unlink(*Dir["#{dir}/*"])
        Dir.unlink(dir)
      rescue Errno::ENOENT
      end

      def write_record_files(name, records)
        dir = "#{RecordStore.zones_path}/#{name}"
        Dir.mkdir(dir)
        records.group_by { |record| [record.fetch(:fqdn), record.fetch(:type)] }.each do |(fqdn, type), grouped_records|
          grouped_records.each do |record|
            record.delete(:fqdn)
            record.delete(:type)
            record.deep_stringify_keys!
          end
          grouped_records = grouped_records.first if grouped_records.size == 1
          domain = fqdn.chomp('.').chomp(name).chomp('.')
          write_yml_file("#{dir}/#{type}__#{domain}.yml", grouped_records)
        end
      end

      def yaml_files
        Dir["#{RecordStore.zones_path}/*.yml"]
      end
    end
  end
end
