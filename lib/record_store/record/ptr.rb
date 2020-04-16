module RecordStore
  class Record::PTR < Record
    attr_accessor :ptrdname

    validate :validate_fqdn_inside_in_addr_arpa_zone

    def initialize(record)
      super

      @ptrdname = Record.ensure_ends_with_dot(record.fetch(:ptrdname))
    end

    def rdata
      { ptrdname: ptrdname }
    end

    def rdata_txt
      ptrdname.to_s
    end

    def validate_fqdn_inside_in_addr_arpa_zone
      errors.add(:fqdn, 'must be in the `in-addr.arpa.` zone') unless fqdn.end_with?('in-addr.arpa.')
    end
  end
end
