module RecordStore
  class Record::ALIAS < Record
    attr_accessor :cname

    validates :cname, presence: true, format: { with: Record::CNAME_REGEX, message: 'is not a fully qualified domain name' }

    def initialize(record)
      super
      @cname = Record.ensure_ends_with_dot(record.fetch(:cname))
    end

    def rdata
      { cname: cname }
    end

    def to_s
      "[ALIASRecord] #{fqdn} #{ttl} IN ALIAS #{cname}"
    end
  end
end
