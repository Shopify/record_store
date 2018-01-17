module RecordStore
  class Changeset
    class Change
      attr_accessor :type, :record, :id

      def initialize(type: nil, record: nil, id: nil)
        @type, @record, @id = type, record, id
      end

      def self.addition(record)
        new(type: :addition, record: record)
      end

      def self.removal(record)
        new(type: :removal, record: record)
      end

      def self.update(id, record)
        new(type: :update, record: record, id: id)
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

    def self.build_from(provider:, zone:)
      current_zone = provider.build_zone(zone_name: zone.unrooted_name, config: zone.config)

      self.new(
        current_records: current_zone.records,
        desired_records: zone.records,
        provider: provider,
        zone: zone.unrooted_name
      )
    end

    def initialize(current_records: [], desired_records: [], provider:, zone:)
      @current_records = Set.new(current_records)
      @desired_records = Set.new(desired_records)
      @provider = provider
      @zone = zone

      @additions, @removals, @updates = [], [], []

      build_changeset
    end

    def apply
      provider.apply_changeset(self)
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
      current_records_set.default_proc = desired_records_set.default_proc = Proc.new{Array.new}

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
