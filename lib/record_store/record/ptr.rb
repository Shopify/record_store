module RecordStore
  class Record::PTR < Record
    attr_accessor :ptrdname

    # IPv4: 1-3 digits (0-255) followed by dots, 1-4 times
    IPV4_LABEL_SEQUENCE_REGEX = /\A(?:([0-9]|[1-9][0-9]|[1-9][0-9][0-9])\.){1,4}/

    # IPv6: single hex digit followed by dots, exactly 32 times
    IPV6_LABEL_SEQUENCE_REGEX = /\A(?:[0-9a-f]\.){32}/i

    IN_ADDR_ARPA_SUFFIX_REGEX = /(in-addr|ip6)\.arpa\.\z/

    # Combine with suffix for full validation
    IPV4_FORMAT_REGEX = Regexp.new(IPV4_LABEL_SEQUENCE_REGEX.source + 'in-addr\.arpa\.\z')
    IPV6_FORMAT_REGEX = Regexp.new(IPV6_LABEL_SEQUENCE_REGEX.source + 'ip6\.arpa\.\z')

    validates_format_of :fqdn, with: Regexp.union(IPV4_FORMAT_REGEX, IPV6_FORMAT_REGEX)

    validate :validate_fqdn_octets_in_range
    validate :validate_fqdn_is_in_addr_arpa_subzone

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
      if fqdn.end_with?('in-addr.arpa.')
        # IPv4 validation: each octet must be 0-255
        IPV4_LABEL_SEQUENCE_REGEX.match(fqdn) do |m|
          unless m.captures.all? { |o| o.to_i.between?(0, 255) }
            errors.add(:fqdn, 'IPv4 octet labels must be within the range 0-255')
          end
        end
      elsif fqdn.end_with?('ip6.arpa.')
        # IPv6 validation: each nibble must be a valid hex digit
        IPV6_LABEL_SEQUENCE_REGEX.match(fqdn) do |m|
          nibbles = m[0].split('.').reject(&:empty?)
          unless nibbles.all? { |n| n.match?(/\A[0-9a-f]\z/i) }
            errors.add(:fqdn, 'IPv6 labels must be single hexadecimal digits (0-9, a-f)')
          end
        end
      end
    end

    def validate_fqdn_is_in_addr_arpa_subzone
      unless IN_ADDR_ARPA_SUFFIX_REGEX.match?(fqdn)
        errors.add(:fqdn, 'PTR records may only exist in the in-addr.arpa zone')
      end
    end
  end
end
