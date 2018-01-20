module RecordStore
  class Record::SPF < Record
    attr_accessor :txtdata

    validates :txtdata, presence: true, length: { maximum: 255 }

    def initialize(record)
      super
      @txtdata = record.fetch(:txtdata)
    end

    def to_s
      "[SPFRecord] #{fqdn} #{ttl} IN SPF \"#{rdata_txt}\""
    end

    def rdata
      { txtdata: txtdata }
    end

    def rdata_txt
      txtdata
    end
  end
end
