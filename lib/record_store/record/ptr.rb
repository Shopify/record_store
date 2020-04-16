module RecordStore
  class Record::PTR < Record
    attr_accessor :ptrdname

    OCTET_LABEL_SEQUENCE_REGEX = /\A(([0-9]|[1-9][0-9]|[1-9][0-9][0-9])\.){1,4}/
    IN_ADDR_ARPA_SUFFIX_REGEX = /in-addr\.arpa\.\z/
    FQDN_FORMAT_REGEX = Regexp.new(OCTET_LABEL_SEQUENCE_REGEX.source + IN_ADDR_ARPA_SUFFIX_REGEX.source)

    validates_format_of :fqdn, with: FQDN_FORMAT_REGEX
    validate :validate_fqdn_octets_in_range

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

    def validate_fqdn_octets_in_range
      OCTET_LABEL_SEQUENCE_REGEX.match(fqdn) do |m|
        unless m.captures.all? { |o| o.to_d.between?(0, 255) }
          errors.add(:fqdn, 'octet labels must be within the range 0-255')
        end
      end

      unless IN_ADDR_ARPA_SUFFIX_REGEX.match?(fqdn)
        errors.add(:fqdn, 'PTR records may only exist in the in-addr.arpa zone')
      end
    end
  end
end
