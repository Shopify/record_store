module RecordStore
  class Record::SRV < Record
    attr_accessor :priority, :port, :weight, :target

    validates :priority, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :port, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :weight, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :target, presence: true, format: { with: Record::CNAME_REGEX, message: 'is not a fully qualified domain name' }

    def initialize(record)
      super
      @priority = record.fetch(:priority)
      @weight   = record.fetch(:weight)
      @port     = record.fetch(:port)
      @target   = record.fetch(:target)
    end

    def to_s
      "[SRVRecord] #{fqdn} #{ttl} IN SRV #{priority} #{weight} #{port} #{target}"
    end

    def rdata
      { priority: priority, port: port, weight: weight, target: target }
    end

  end
end
