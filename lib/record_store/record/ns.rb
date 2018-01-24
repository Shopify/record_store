module RecordStore
  class Record::NS < Record
    attr_accessor :nsdname

    validates :nsdname, presence: true, format: { with: Record::FQDN_REGEX, message: 'is not a fully qualified domain name' }

    def initialize(record)
      super
      @nsdname = Record.ensure_ends_with_dot(record.fetch(:nsdname))
    end

    def rdata
      { nsdname: nsdname }
    end

    def rdata_txt
      nsdname
    end
  end
end
