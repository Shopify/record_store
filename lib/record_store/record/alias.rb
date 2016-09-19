module RecordStore
  class Record::ALIAS < Record
    attr_accessor :alias

    validates :alias, presence: true, format: { with: Record::CNAME_REGEX, message: 'is not a fully qualified domain name' }

    def initialize(record)
      super
      @alias = Record.ensure_ends_with_dot(record.fetch(:alias))
    end

    def rdata
      { alias: self.alias }
    end

    def to_s
      "[ALIASRecord] #{fqdn} #{ttl} IN ALIAS #{self.alias}"
    end
  end
end
