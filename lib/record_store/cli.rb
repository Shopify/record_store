require 'English'

module RecordStore
  class CLI < Thor
    class_option :config, desc: 'Path to config.yml', aliases: '-c'
    FORMATS = %w[file directory]

    def initialize(*args)
      super
      RecordStore.config_path = options.fetch('config', "#{Dir.pwd}/config.yml")
    end

    def self.exit_on_failure?
      true
    end

    desc 'thaw', 'Thaws all zones under management to allow manual edits'
    def thaw
      Zone.each do |_, zone|
        zone.providers.each do |provider|
          provider.thaw_zone(zone.unrooted_name) if provider.thawable?
        end
      end
    end

    desc 'freeze', 'Freezes all zones under management to prevent manual edits'
    def freeze
      Zone.each do |_, zone|
        zone.providers.each do |provider|
          provider.freeze_zone(zone.unrooted_name) if provider.freezable?
        end
      end
    end

    desc 'info', 'Show information about zones under management'
    option :delegation, desc: 'Include delegation', aliases: '-d', type: :boolean, default: false
    def info
      Zone.each do |name, zone|
        puts "\n"
        puts "Zone: #{name}"
        puts "Providers:"
        zone.config.providers.each { |p| puts "- #{p}" }
        if (delegation = zone.fetch_authority)
          puts "Authoritative nameservers:"
          delegation.each { |d| puts "- #{d}" }
        else
          $stderr.puts "ERROR: Unable to determine delegation (#{name})"
        end
      end
    end

    desc 'list', 'Lists out records in YAML zonefiles'
    option :all, desc: 'Show all records', aliases: '-a', type: :boolean, default: false
    def list
      Zone.each do |name, zone|
        puts "Zone: #{name}"
        records = options.fetch('all') ? zone.all : zone.records
        records.each(&:log!)
      end
    end

    desc 'diff [ZONE ...]', 'Displays the DNS differences between the zone files in this repo and production'
    option :all, desc: 'Include all records', aliases: '-a', type: :boolean, default: false
    option :verbose, desc: 'Print records that haven\'t diverged', aliases: '-v', type: :boolean, default: false
    def diff(*zones)
      puts "Diffing #{zones.any? ? zones.count : Zone.defined.count} zone(s)"

      all = options.fetch('all')

      Zone.each do |name, zone|
        next unless zones.empty? || zones.include?(name)

        changesets = zone.build_changesets(all: all)

        if !options.fetch('verbose') && changesets.all?(&:empty?)
          print_and_flush('.')
          next
        else
          puts "\n"
          puts "Zone: #{name}"
        end

        changesets.each do |changeset|
          next if !options.fetch('verbose') && changeset.changes.empty?

          puts '-' * 20
          puts "Provider: #{changeset.provider}"

          if changeset.additions.any?
            puts "Add:"
            changeset.additions.map(&:record).each do |record|
              puts " - #{record}"
            end
          end

          if changeset.removals.any?
            puts "Remove:"
            changeset.removals.map(&:record).each do |record|
              puts " - #{record}"
            end
          end

          if changeset.updates.any?
            puts "Update:"
            changeset.updates.map(&:record).each do |record|
              puts " - #{record}"
            end
          end

          next unless options.fetch('verbose')
          puts "Unchanged:"
          changeset.unchanged.each do |record|
            puts " - #{record}"
          end
        end
        puts '=' * 20
      end
      puts "\n"
    end

    desc 'apply', 'Applies the DNS changes'
    def apply
      zones = Zone.modified

      if zones.empty?
        puts "No changes to sync"
        exit
      end

      invalid_zones = zones.select(&:invalid?)
      unless invalid_zones.empty?
        error_message = invalid_zones
          .map { |z| "Attempted to apply invalid zone: #{z.name}: #{z.errors.full_messages.join(',')}" }
          .join("\n")

        abort(error_message)
      end

      zones.each do |zone|
        changesets = zone.build_changesets
        changesets.each(&:apply)
      end

      puts "All zone changes deployed"
    end

    option :name, desc: 'Zone to download', aliases: '-n', type: :string, required: true
    option :provider, desc: 'Provider in which this zone exists', aliases: '-p', type: :string
    desc 'download', 'Downloads all records from zone and creates YAML zone definition in zones/ '\
                     'e.g. record-store download --name=shopify.io'
    def download
      name = options.fetch('name')
      abort('Please omit the period at the end of the zone') if name.ends_with?('.')
      abort('Zone with this name already exists in zones/') if File.exist?("#{RecordStore.zones_path}/#{name}.yml")

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

    option :name, desc: 'Zone to reformat', aliases: '-n', type: :string, required: false
    desc 'reformat', 'Sorts and re-outputs the zone (or all zones) as specified format (file)'
    def reformat
      name = options['name']
      zones = name ? [Zone.find(name)] : Zone.all

      zones.each do |zone|
        puts "Writing #{zone.name}"
        zone.write
      end
    end

    option :name, desc: 'Zone to sort', aliases: '-n', type: :string, required: true
    desc 'sort', 'Sorts the zonefile alphabetically e.g. record-store sort --name=shopify.io'
    def sort
      name = options.fetch('name')
      abort("Please omit the period at the end of the zone") if name.ends_with?('.')

      yaml = YAML.load_file("#{RecordStore.zones_path}/#{name}.yml")
      yaml.fetch(name).fetch('records').sort_by! do |r|
        [r.fetch('fqdn'), r.fetch('type'), r['nsdname'] || r['address']]
      end
      File.write("#{RecordStore.zones_path}/#{name}.yml", yaml.deep_stringify_keys.to_yaml.gsub("---\n", ''))
    end

    desc 'secrets', 'Decrypts DynECT credentials'
    def secrets
      environment = if ENV['PRODUCTION']
        'production'
      elsif ENV['CI']
        'ci'
      else
        'dev'
      end

      secrets = %x(ejson decrypt #{RecordStore.secrets_path.sub(/\.json\z/, ".#{environment}.ejson")})
      if $CHILD_STATUS.success?
        File.write(RecordStore.secrets_path, secrets)
      else
        abort(secrets)
      end
    end

    desc 'assert_empty_diff', 'Asserts there is no divergence between DynECT & the zone files'
    def assert_empty_diff
      zones = Zone.modified.map(&:name)

      unless zones.empty?
        abort("The following zones have diverged: #{zones.join(', ')}")
      end
    end

    desc 'validate_authority [ZONE ...]', 'Validates that authoritative nameservers match the providers'
    option :verbose, desc: 'Include valid zones in output', aliases: '-v', type: :boolean, default: false
    def validate_authority(*zones)
      verbose = options.fetch('verbose')

      Zone.each do |name, zone|
        next unless zones.empty? || zones.include?(name)

        authority = zone.fetch_authority

        delegation = Hash.new { |h, k| h[k] = [] }
        authority.each do |ns|
          delegation[Provider.provider_for(ns)] << ns
        end

        delegated = delegation.keys.sort
        configured = zone.config.providers.sort

        ok = configured & delegated
        missing = configured - delegated
        unconfigured = delegated - configured

        next if !verbose && missing.empty? && unconfigured.empty?

        puts "\n"
        puts "Zone: #{name}"

        if verbose
          ok.each do |provider|
            puts "- #{provider}:"
            delegation[provider].each do |ns|
              puts "  - #{ns.nsdname}"
            end
          end
        end

        missing.each do |provider|
          puts "- #{provider}: authoritative nameservers not found for configured provider"
        end

        unconfigured.each do |provider|
          if provider
            puts "- #{provider}: unexpected authoritative nameservers found"
          else
            puts "- Unknown: unknown authoritative nameservers found"
          end

          delegation[provider].each do |ns|
            puts "  - #{ns.nsdname}"
          end
        end
      end
    end

    desc 'validate_records', 'Validates that all DNS records have valid definitions'
    def validate_records
      invalid_zones = []
      Zone.all.reject(&:valid?).each do |zone|
        invalid_zones << zone.unrooted_name

        puts "#{zone.unrooted_name} definition is not valid:"
        puts zone.errors.full_messages.map { |msg| " - #{msg}" }

        invalid_records = zone.records.reject(&:valid?)
        puts '  Invalid records' unless invalid_records.empty?

        invalid_records.each do |record|
          puts "    #{record}"
          record.errors.each do |field, msg|
            puts "      - #{field}: #{msg}"
          end
        end
      end

      if invalid_zones.present?
        abort("The following zones were invalid: #{invalid_zones.join(', ')}")
      else
        puts "All zones have valid definitions."
      end
    end

    desc 'validate_change_size', "Validates no more then particular limit of DNS records are removed per zone at a time"
    def validate_change_size
      zones = Zone.modified

      unless zones.empty?
        removals = zones.select do |zone|
          zone.changeset.removals.size > MAXIMUM_REMOVALS
        end

        unless removals.empty?
          error = +"As a safety measure, you cannot remove more than #{MAXIMUM_REMOVALS} "
          error << 'records at a time per zone. '
          error << "(zones failing this: #{removals.map(&:name).join(', ')})"
          abort(error)
        end
      end
    end

    SKIP_CHECKS = 'SKIP_DEPLOY_VALIDATIONS'
    desc 'validate_initial_state', "Validates state hasn't diverged since the last deploy"
    def validate_initial_state
      assert_empty_diff
      puts "Deploy will cause no changes, no need to validate initial state"
    rescue SystemExit
      if File.exist?(File.expand_path(SKIP_CHECKS, Dir.pwd))
        puts "Found '#{SKIP_CHECKS}', skipping predeploy validations"
      else
        puts "Checkout git SHA #{ENV['LAST_DEPLOYED_SHA']}"
        %x(git checkout #{ENV['LAST_DEPLOYED_SHA']})
        abort("Checkout of old commit failed") unless $CHILD_STATUS.success?

        %x(record-store secrets)
        abort("Decrypt secrets failed") unless $CHILD_STATUS.success?

        %x(record-store assert_empty_diff)
        abort("Dyn status has diverged!") unless $CHILD_STATUS.success?

        puts "Checkout git SHA #{ENV['REVISION']}"
        %x(git checkout #{ENV['REVISION']})
        abort("Checkout of new commit failed") unless $CHILD_STATUS.success?

        %x(record-store secrets)
        abort("Decrypt secrets failed") unless $CHILD_STATUS.success?
      end
    end

    private

    def print_and_flush(str)
      print(str)
      $stdout.flush
    end
  end
end
