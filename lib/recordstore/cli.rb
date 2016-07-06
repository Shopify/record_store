module RecordStore
  class CLI < Thor
    class_option :config, desc: 'Path to config.yml', aliases: '-c'

    def initialize(*args)
      super
      RecordStore.config_path = options.fetch('config', "#{Dir.pwd}/config.yml")
    end

    desc 'thaw', 'Thaws all zones under management to allow manual edits'
    def thaw
      Zone.each do |_, zone|
        zone.provider.thaw if zone.provider.thawable?
      end
    end

    desc 'freeze', 'Freezes all zones under management to prevent manual edits'
    def freeze
      Zone.each do |_, zone|
        zone.provider.freeze_zone if zone.provider.freezable?
      end
    end

    desc 'list', 'Lists out records in YAML zonefiles'
    def list
      Zone.each do |name, zone|
        puts "Zone: #{name}"
        zone.records.each do |record|
          record.log!
        end
      end
    end

    option :verbose, desc: 'Print records that haven\'t diverged', aliases: '-v', type: :boolean, default: false
    desc 'diff', 'Displays the DNS differences between the zone files in this repo and production'
    def diff
      Zone.each do |name, zone|
        puts "Zone: #{name}"

        diff = zone.changeset

        if !diff.additions.empty? || options.fetch('verbose')
          puts "Add:"
          diff.additions.map(&:record).each do |record|
            puts " - #{record.to_s}"
          end
        end

        if !diff.removals.empty? || options.fetch('verbose')
          puts "Remove:"
          diff.removals.map(&:record).each do |record|
            puts " - #{record.to_s}"
          end
        end

        if !diff.updates.empty? || options.fetch('verbose')
          puts "Update:"
          diff.updates.map(&:record).each do |record|
            puts " - #{record.to_s}"
          end
        end

        if options.fetch('verbose')
          puts "Unchanged:"
          diff.unchanged.each do |record|
            puts " - #{record.to_s}"
          end
        end

        puts "Empty diff" if diff.changes.empty?
        puts '=' * 20
      end
    end

    desc 'apply', 'Applies the DNS changes'
    def apply
      zones = zones_modified

      if zones.empty?
        puts "No changes to sync"
        exit
      end

      zones.each do |zone|
        abort "Attempted to apply invalid zone: #{zone.name}" unless zone.valid?
        provider = zone.provider
        provider.apply_changeset(zone.changeset)
      end

      puts "All zone changes deployed"
    end

    option :name, desc: 'Zone to download', aliases: '-n', type: :string, required: true
    option :provider, desc: 'Provider in which this zone exists', aliases: '-p', type: :string
    desc 'download', 'Downloads all records from zone and creates YAML zone definition in zones/ e.g. record-store download --name=shopify.io'
    def download
      name = options.fetch('name')
      abort 'Please omit the period at the end of the zone' if name.ends_with?('.')
      abort 'Zone with this name already exists in zones/' if File.exists?("#{RecordStore.zones_path}/#{name}.yml")

      provider = options.fetch('provider', Provider.provider_for(name))
      if provider.nil?
        puts "Could not find valid provider from #{name} SOA record"
        provider = ask("Please enter the provider in which #{name} exists")
      else
        puts "Identified #{provider} as the DNS provider"
      end

      puts "Downloading records for #{name}"
      Zone.download(name, provider)
      puts "Records have been downloaded & can be found in zones/#{name}.yml"
    end

    option :name, desc: 'Zone to sort', aliases: '-n', type: :string, required: true
    desc 'sort', 'Sorts the zonefile alphabetically e.g. record-store sort --name=shopify.io'
    def sort
      name = options.fetch('name')
      abort "Please omit the period at the end of the zone" if name.ends_with?('.')

      yaml = YAML.load_file("#{RecordStore.zones_path}/#{name}.yml")
      yaml.fetch(name).fetch('records').sort_by! { |r| [r.fetch('fqdn'), r.fetch('type'), r['nsdname'] || r['address']] }

      File.write("#{RecordStore.zones_path}/#{name}.yml", yaml.deep_stringify_keys.to_yaml.gsub("---\n", ''))
    end

    desc 'secrets', 'Decrypts DynECT credentials'
    def secrets
      environment = begin
        if ENV['PRODUCTION']
          'production'
        elsif ENV['CI']
          'ci'
        else
          'dev'
        end
      end

      secrets = `ejson decrypt #{RecordStore.secrets_path.sub(/\.json\z/, ".#{environment}.ejson")}`
      if $?.exitstatus == 0
        File.write(RecordStore.secrets_path, secrets)
      else
        abort secrets
      end
    end

    desc 'assert_empty_diff', 'Asserts there is no divergence between DynECT & the zone files'
    def assert_empty_diff
      zones = zones_modified.map(&:name)

      unless zones.empty?
        abort "The following zones have diverged: #{zones.join(', ')}"
      end
    end

    desc 'validate_records', 'Validates that all DNS records have valid definitions'
    def validate_records
      invalid_zones = []
      Zone.each do |name, zone|
        if !zone.valid?
          invalid_zones << name

          puts "#{name} definition is not valid:"
          zone.errors.each do |field, msg|
            puts " - #{field}: #{msg}"
          end

          invalid_records = zone.records.reject(&:valid?)
          puts '  Invalid records' if invalid_records.size > 0

          invalid_records.each do |record|
            puts "    #{record.to_s}"
            record.errors.each do |field, msg|
              puts "      - #{field}: #{msg}"
            end
          end
        end
      end

      if invalid_zones.size > 0
        abort "The following zones were invalid: #{invalid_zones.join(', ')}"
      else
        puts "All records have valid definitions."
      end
    end

    desc 'validate_change_size', "Validates no more then particular limit of DNS records are removed per zone at a time"
    def validate_change_size
      zones = zones_modified

      unless zones.empty?
        removals = zones.select do |zone|
          zone.changeset.removals.size > MAXIMUM_REMOVALS
        end

        unless removals.empty?
          abort "As a safety measure, you cannot remove more than #{MAXIMUM_REMOVALS} records at a time per zone. (zones failing this: #{removals.map(&:name).join(', ')})"
        end
      end
    end

    desc 'validate_all_present', 'Validates that all the zones that are expected are defined'
    def validate_all_present
      defined_zones = Set.new(RecordStore.defined_zones)
      expected_zones = Set.new(RecordStore.expected_zones)

      missing_zones = expected_zones - defined_zones
      extra_zones = defined_zones - expected_zones

      unless missing_zones.empty?
        abort "The following zones are missing: #{missing_zones.to_a.join(', ')}"
      end

      unless extra_zones.empty?
        abort "The following unexpected zones are defined: #{extra_zones.to_a.join(', ')}"
      end
    end

    SKIP_CHECKS = 'SKIP_DEPLOY_VALIDATIONS'
    desc 'validate_initial_state', "Validates state hasn't diverged since the last deploy"
    def validate_initial_state
      begin
        assert_empty_diff
        puts "Deploy will cause no changes, no need to validate initial state"
      rescue SystemExit
        if File.exists?(File.expand_path(SKIP_CHECKS, Dir.pwd))
          puts "Found '#{SKIP_CHECKS}', skipping predeploy validations"
        else
          puts "Checkout git SHA #{ENV['LAST_DEPLOYED_SHA']}"
          `git checkout #{ENV['LAST_DEPLOYED_SHA']}`
          abort "Checkout of old commit failed" if $?.exitstatus != 0

          `record-store assert_empty_diff`
          abort "Dyn status has diverged!" if $?.exitstatus != 0

          puts "Checkout git SHA #{ENV['REVISION']}"
          `git checkout #{ENV['REVISION']}`
          abort "Checkout of new commit failed" if $?.exitstatus != 0
        end
      end
    end

    private

    def zones_modified
      modified_zones, mutex = [], Mutex.new
      Zone.all.map do |zone|
        thread = Thread.new do
          mutex.synchronize {modified_zones << zone} unless zone.unchanged?
        end
      end.each(&:join)

      modified_zones
    end
  end
end
