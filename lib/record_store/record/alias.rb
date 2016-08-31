module RecordStore
  class Record::ALIAS < Record
    attr_accessor :alias_value

    validates :alias_value, presence: true, format: { with: Record::CNAME_REGEX, message: 'is not a fully qualified domain name' }

    def initialize(record)
      super
      @alias_value = Record.ensure_ends_with_dot(record.fetch(:alias))
    end

    def rdata
      { alias: alias_value }
    end

    def to_s
      "[ALIASRecord] #{fqdn} #{ttl} IN ALIAS #{alias_value}"
    end
  end
end
