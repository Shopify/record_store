module RecordStore
  class Record::HTTPS < Record
    attr_accessor :priority, :target, :value

    # RFC 9460 §2.1 & Appendix A presentation form: whitespace-separated lowercase `key` or `key=value` tokens,
    # where escapes are either a 3-digit decimal octet (000-255) or an escaped non-digit character.
    ESCAPE_REGEX = /\\(?:[01]\d\d|2[0-4]\d|25[0-5]|[^0-9\r\n])/
    QUOTED_VALUE_REGEX = /"(?:#{ESCAPE_REGEX}|[^"\\\r\n])*"/
    UNQUOTED_VALUE_REGEX = /(?:#{ESCAPE_REGEX}|[^\s"\\])+/
    SVC_PARAM_REGEX = /([a-z0-9-]+)(?:=(#{QUOTED_VALUE_REGEX}|#{UNQUOTED_VALUE_REGEX}))?/
    SVC_PARAMS_REGEX = /\A#{SVC_PARAM_REGEX}(?:\s+#{SVC_PARAM_REGEX})*\z/

    REGISTERED_KEYS = {
      'mandatory' => 0,
      'alpn' => 1,
      'no-default-alpn' => 2,
      'port' => 3,
      'ipv4hint' => 4,
      'ech' => 5,
      'ipv6hint' => 6,
    }.freeze
    VALUE_REQUIRED_KEYS = %w(alpn port ipv4hint ipv6hint ech mandatory).freeze

    validates :priority, presence: true, numericality: {
      only_integer: true,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 65535,
    }
    validates :target, presence: true, format: {
      with: Regexp.union(/\A\.\z/, Record::CNAME_REGEX),
      message: 'must be "." or a fully qualified domain name',
    }
    validate :validate_value

    def initialize(record)
      super

      @priority = normalize_priority(record.fetch(:priority))
      @target = normalize_target(record.fetch(:target))
      @value = record[:value].to_s.strip
    end

    def rdata
      {
        priority: priority,
        target: target,
        value: value,
      }
    end

    def rdata_txt
      value.empty? ? "#{priority} #{target}" : "#{priority} #{target} #{value}"
    end

    private

    # SvcPriority 0 is AliasMode (RFC 9460 §2.4.2); any non-zero value is ServiceMode.
    def alias_mode?
      priority == 0
    end

    def normalize_priority(raw_priority)
      return raw_priority unless raw_priority.is_a?(String)

      Integer(raw_priority, 10, exception: false) || raw_priority
    end

    def normalize_target(raw_target)
      return raw_target unless raw_target.is_a?(String) && !raw_target.empty?

      Record.ensure_ends_with_dot(raw_target)
    end

    def validate_value
      if alias_mode?
        errors.add(:value, 'must be empty in AliasMode (priority 0)') unless value.empty?
        return
      end

      return if value.empty?

      unless value.match?(SVC_PARAMS_REGEX)
        errors.add(:value, 'is not a valid SvcParams list')
        return
      end

      params = parse_svc_params
      return unless params

      validate_svc_params(params)
    end

    def parse_svc_params
      params = {}
      value.scan(SVC_PARAM_REGEX) do |key, raw_val|
        key_id = canonical_key(key)
        if key_id.nil?
          errors.add(:value, "contains invalid SvcParam key: #{key}")
          return nil
        end
        if params.key?(key_id)
          errors.add(:value, "contains duplicate SvcParam key: #{key}")
          return nil
        end
        params[key_id] = [key, raw_val]
      end
      params
    end

    def canonical_key(key)
      return if key.length > 63

      if key.match?(/\Akey\d+\z/)
        return if key.match?(/\Akey0\d/)

        num = key.delete_prefix('key').to_i
        return if num > 65535

        num
      else
        REGISTERED_KEYS.fetch(key, key)
      end
    end

    def validate_svc_params(params)
      params.each do |key_id, (key, raw_val)|
        unquoted = raw_val ? unquote_param(raw_val) : nil

        if key_id == REGISTERED_KEYS['no-default-alpn']
          errors.add(:value, 'no-default-alpn must not have a value') unless unquoted.nil? || unquoted.empty?
          errors.add(:value, 'no-default-alpn requires alpn') unless params.key?(REGISTERED_KEYS['alpn'])
        elsif VALUE_REQUIRED_KEYS.include?(key) && (unquoted.nil? || unquoted.empty?)
          errors.add(:value, "#{key} requires a non-empty value")
        elsif key == 'alpn'
          validate_alpn_param(unquoted)
        elsif key == 'port'
          validate_port_param(unquoted)
        elsif key == 'ipv4hint'
          validate_ip_hints(unquoted, :ipv4?, 'ipv4hint')
        elsif key == 'ipv6hint'
          validate_ip_hints(unquoted, :ipv6?, 'ipv6hint')
        elsif key == 'mandatory'
          validate_mandatory_param(unquoted, params)
        elsif key_id == REGISTERED_KEYS['mandatory']
          validate_mandatory_wire_param(unquoted, params)
        end
      end
    end

    def unquote_param(raw_val)
      raw_val.start_with?('"') ? raw_val[1..-2] : raw_val
    end

    def decode_char_string(str)
      str.b.gsub(ESCAPE_REGEX) do |match|
        esc = match[1..]
        esc.match?(/\A\d{3}\z/) ? esc.to_i.chr(Encoding::BINARY) : esc
      end
    end

    def validate_alpn_param(alpn)
      stage1 = decode_char_string(alpn)
      ids = [''.b]
      i = 0
      while i < stage1.bytesize
        byte = stage1.getbyte(i)
        if byte == 0x5C # '\\'
          next_byte = stage1.getbyte(i + 1)
          unless next_byte == 0x2C || next_byte == 0x5C
            errors.add(:value, 'alpn contains an invalid escape')
            return
          end
          ids.last << next_byte
          i += 2
        elsif byte == 0x2C # ','
          ids << ''.b
          i += 1
        else
          ids.last << byte
          i += 1
        end
      end

      return if ids.all? { |id| !id.empty? && id.bytesize <= 255 }

      errors.add(:value, 'alpn entries must be 1 to 255 octets')
    end

    def validate_port_param(port)
      return if port.match?(/\A\d+\z/) && port.to_i <= 65535

      errors.add(:value, 'port must be an integer between 0 and 65535')
    end

    def validate_ip_hints(list, predicate, key)
      ips = list.split(',', -1)
      valid = ips.all? do |ip|
        ip.match?(/\A[0-9a-fA-F.:]+\z/) && IPAddr.new(ip).public_send(predicate)
      rescue IPAddr::InvalidAddressError
        false
      end
      errors.add(:value, "#{key} contains an invalid IP address") unless valid
    end

    def validate_mandatory_param(list, params)
      keys = list.split(',', -1)
      if keys.any?(&:empty?)
        errors.add(:value, 'mandatory must list unique non-empty keys')
        return
      end

      key_ids = keys.map { |k| canonical_key(k) }
      if key_ids.any?(&:nil?)
        errors.add(:value, 'mandatory contains an invalid key')
      elsif key_ids.uniq.length != key_ids.length
        errors.add(:value, 'mandatory must list unique non-empty keys')
      elsif key_ids.include?(REGISTERED_KEYS['mandatory'])
        errors.add(:value, 'mandatory must not include itself')
      elsif key_ids.any? { |id| !params.key?(id) }
        errors.add(:value, 'mandatory references a key that is not present')
      end
    end

    def validate_mandatory_wire_param(raw, params)
      wire = raw ? decode_char_string(raw) : ''.b
      if wire.empty? || wire.bytesize.odd?
        errors.add(:value, 'mandatory wire value must be a non-empty list of 16-bit key ids')
        return
      end

      key_ids = wire.unpack('n*')
      if key_ids != key_ids.sort || key_ids.uniq.length != key_ids.length ||
          key_ids.include?(REGISTERED_KEYS['mandatory']) || key_ids.any? { |id| !params.key?(id) }
        errors.add(:value, 'mandatory references missing, unsorted, duplicate, or self key ids')
      end
    end
  end
end
