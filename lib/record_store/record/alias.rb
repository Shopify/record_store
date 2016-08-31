module RecordStore
  class Record::ALIAS < Record
    attr_accessor :t

    validates :t, presence: true, format: { with: Record::CNAME_REGEX, message: 'is not a fully qualified domain name' }

    def initialize(record)
      super
      @t = Record.ensure_ends_with_dot(record.fetch(:t))
    end

    def rdata
      { t: t }
    end

    def to_s
      "[ALIASRecord] #{fqdn} #{ttl} IN ALIAS #{t}"
    end
  end
end
