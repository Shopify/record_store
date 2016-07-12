module RecordStore
  class Record::SPF < Record
    attr_accessor :txtdata

    validates :txtdata, presence: true, length: { maximum: 255 }

    def initialize(record)
      super
      @txtdata = record.fetch(:txtdata)
    end

    def to_s
      "[SPFRecord] #{fqdn} #{ttl} IN SPF \"#{txtdata}\""
    end

    def rdata
      { txtdata: txtdata }
    end
  end
end
