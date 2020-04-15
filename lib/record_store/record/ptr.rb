module RecordStore
  class Record::PTR < Record
    attr_accessor :ptrdname

    validate :validate_fqdn_inside_in_addr_arpa_zone
    validate :validate_ptrdname_is_rooted

    def initialize(record)
      super

      @ptrdname = record.fetch(:ptrdname)
    end

    def rdata_txt
      ptrdname.to_s
    end

    def validate_fqdn_inside_in_addr_arpa_zone
      errors.add(:fqdn, 'must be in the `in-addr.arpa.` zone') unless fqdn.end_with?('in-addr.arpa.')
    end

    def validate_ptrdname_is_rooted
      errors.add(:ptrdname, 'ptrdname must be explicitly rooted') unless ptrdname.end_with?('.')
    end
  end
end
