module RecordStore
  class Changeset
    class Change
      attr_accessor :type, :record, :id

      def initialize(type: nil, record: nil, id: nil)
        @type = type
        @record = record
        @id = id
      end

      class << self
        def addition(record)
          new(type: :addition, record: record)
        end

        def removal(record)
          new(type: :removal, record: record)
        end

        def update(id, record)
          new(type: :update, record: record, id: id)
        end
      end

      def removal?
        type == :removal
      end

      def addition?
        type == :addition
      end

      def update?
        type == :update
      end
    end

    attr_reader :current_records, :desired_records, :removals, :additions, :updates, :provider, :zone

    class << self
      def build_from(provider:, zone:, all: false)
        current_zone = provider.build_zone(zone_name: zone.unrooted_name, config: zone.config)

        current_records = all ? current_zone.all : current_zone.records
        desired_records = all ? zone.all : zone.records

        new(
          current_records: current_records,
          desired_records: desired_records,
          provider: provider,
          zone: zone.unrooted_name,
        )
      end
    end

    def initialize(current_records: [], desired_records: [], provider:, zone:)
      @current_records = Set.new(current_records)
      @desired_records = Set.new(desired_records)
      @provider = provider
      @zone = zone

      @additions = []
      @removals = []
      @updates = []

      build_changeset
    end

    def apply
      puts "Applying #{additions.size} additions, #{removals.size} removals, and #{updates.size} updates..."

      provider.apply_changeset(self)

      puts "Published #{zone} changes to #{provider}\n\n"
    end

    def unchanged
      current_records & desired_records
    end

    def changes
      updates.to_a + removals.to_a + additions.to_a
    end

    def empty?
      changes.empty?
    end

    private

    def build_changeset
      current_records_set = (current_records - unchanged).sort_by(&:to_s).group_by(&:key)
      desired_records_set = (desired_records - unchanged).sort_by(&:to_s).group_by(&:key)
      current_records_set.default_proc = desired_records_set.default_proc = proc { [] }

      record_keys = current_records_set.keys | desired_records_set.keys

      diff = record_keys.flat_map do |key|
        # the array being zipped over must be bigger then or equal to the other array for zip to work
        buffer = [0, desired_records_set[key].size - current_records_set[key].size].max
        temp_diff = current_records_set[key] + [nil] * buffer

        temp_diff.zip(desired_records_set[key])
      end

      diff.each do |before_rr, after_rr|
        if before_rr.nil?
          @additions << Change.addition(after_rr)
        elsif after_rr.nil?
          @removals << Change.removal(before_rr)
        else
          @updates << Change.update(before_rr.id, after_rr)
        end
      end
    end
  end
end
