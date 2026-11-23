module RecordStore
  class Record::HTTPS < Record
    attr_accessor :priority, :target, :value

    # RFC 9460 §2.1 & Appendix A presentation form: horizontal-whitespace-separated lowercase `key` or `key=value`
    # tokens, where escapes are either a 3-digit decimal octet (000-255) or an escaped non-digit character.
    ESCAPE_REGEX = /\\(?:[01]\d\d|2[0-4]\d|25[0-5]|[^0-9\r\n])/
    QUOTED_VALUE_REGEX = /"(?:#{ESCAPE_REGEX}|[^"\\\r\n])*"/
    UNQUOTED_VALUE_REGEX = /(?:#{ESCAPE_REGEX}|[^\s"\\;()])+/
    SVC_PARAM_REGEX = /([a-z0-9-]+)(?:=(#{QUOTED_VALUE_REGEX}|#{UNQUOTED_VALUE_REGEX}))?/
    SVC_PARAMS_REGEX = /\A#{SVC_PARAM_REGEX}(?:[ \t]+#{SVC_PARAM_REGEX})*\z/
    ALPN_ID_REGEX = /(?:\\[\\,]|[^\\,])+/n
    ALPN_REGEX = /\A#{ALPN_ID_REGEX}(?:,#{ALPN_ID_REGEX})*\z/n

    REGISTERED_KEY_IDS = {
      0 => 'mandatory',
      1 => 'alpn',
      2 => 'no-default-alpn',
      3 => 'port',
      4 => 'ipv4hint',
      5 => 'ech',
      6 => 'ipv6hint',
      7 => 'dohpath',
      8 => 'ohttp',
      9 => 'tls-supported-groups',
    }.freeze
    REGISTERED_KEY_NAMES = REGISTERED_KEY_IDS.values.to_set.freeze

    validates :priority, presence: true, numericality: {
      only_integer: true,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 65535,
    }
    validates :target, presence: true, length: { maximum: 254 }, format: {
      with: Regexp.union(/\A\.\z/, Record::CNAME_REGEX),
      message: 'must be "." or a fully qualified domain name',
    }
    validate :validate_target_label_length
    validate :validate_value

    def initialize(record)
      super

      @priority = normalize_priority(record.fetch(:priority))
      @target = normalize_target(record.fetch(:target))
      @value = normalize_value(record[:value])
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

    def normalize_value(raw_value)
      str = raw_value.to_s.sub(/\A[ \t]+/, '')
      while str.end_with?(' ', "\t")
        preceding_backslashes = str[0...-1][/\\*\z/].length
        break if preceding_backslashes.odd?

        str = str[0...-1]
      end
      return str if str.empty? || !str.match?(SVC_PARAMS_REGEX)

      canonicalize_svc_params(str)
    end

    def canonicalize_svc_params(str)
      str.scan(SVC_PARAM_REGEX).map do |key, raw_val|
        inner = raw_val ? unquote_param(raw_val) : ''
        inner = canonicalize_param_value(key, inner)
        %(#{key}="#{inner}")
      end.join(' ')
    end

    def canonicalize_param_value(key, val)
      case key
      when 'port'
        val.match?(/\A\d+\z/) ? val.to_i.to_s : val
      when 'ipv4hint'
        normalize_ip_list(val, :ipv4?)
      when 'ipv6hint'
        normalize_ip_list(val, :ipv6?)
      else
        val
      end
    end

    def normalize_ip_list(list, predicate)
      return list if list.empty?

      ips = list.split(',', -1)
      normalized = ips.map do |ip|
        return list unless ip.match?(/\A[0-9a-fA-F.:]+\z/)

        addr = IPAddr.new(ip)
        return list unless addr.public_send(predicate)

        addr.to_s
      end
      normalized.join(',')
    rescue IPAddr::InvalidAddressError
      list
    end

    def validate_target_label_length
      return unless target.is_a?(String)
      return if target.split('.').all? { |label| label.length <= 63 }

      errors.add(:target, 'label should be at most 63 characters')
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
        error = key_error(key)
        if error
          errors.add(:value, error)
          return nil
        end
        if params.key?(key)
          errors.add(:value, "contains duplicate SvcParam key: #{key}")
          return nil
        end
        params[key] = raw_val
      end
      params
    end

    def key_error(key)
      return if REGISTERED_KEY_NAMES.include?(key)

      if key.match?(/\Akey(?:0|[1-9]\d*)\z/)
        num = key.delete_prefix('key').to_i
        return "contains invalid SvcParam key: #{key}" if num > 65534

        registered = REGISTERED_KEY_IDS[num]
        return "use #{registered} instead of #{key}" if registered

        return
      end

      "contains unknown SvcParam key: #{key}"
    end

    def validate_svc_params(params)
      params.each do |key, raw_val|
        unquoted = raw_val ? unquote_param(raw_val) : nil

        case key
        when 'no-default-alpn'
          errors.add(:value, 'no-default-alpn must not have a value') unless unquoted.nil? || unquoted.empty?
          errors.add(:value, 'no-default-alpn requires alpn') unless params.key?('alpn')
        when 'ohttp'
          errors.add(:value, 'ohttp must not have a value') unless unquoted.nil? || unquoted.empty?
        when 'alpn'
          validate_alpn_param(unquoted)
        when 'port'
          validate_port_param(unquoted)
        when 'ipv4hint'
          validate_ip_hints(unquoted, :ipv4?, 'ipv4hint')
        when 'ipv6hint'
          validate_ip_hints(unquoted, :ipv6?, 'ipv6hint')
        when 'ech', 'dohpath', 'tls-supported-groups'
          errors.add(:value, "#{key} requires a non-empty value") if unquoted.nil? || unquoted.empty?
        when 'mandatory'
          validate_mandatory_param(unquoted, params)
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
      if alpn && !alpn.empty?
        stage1 = decode_char_string(alpn)
        if stage1.match?(ALPN_REGEX) &&
            stage1.scan(ALPN_ID_REGEX).all? { |id| id.gsub(/\\[\\,]/n, 'x').bytesize <= 255 }
          return
        end
      end

      errors.add(:value, 'alpn entries must be 1 to 255 octets')
    end

    def validate_port_param(port)
      return if port&.match?(/\A\d+\z/) && port.to_i <= 65535

      errors.add(:value, 'port must be an integer between 0 and 65535')
    end

    def validate_ip_hints(list, predicate, key)
      ips = list.nil? || list.empty? ? [] : list.split(',', -1)
      valid = !ips.empty? && ips.all? do |ip|
        ip.match?(/\A[0-9a-fA-F.:]+\z/) && IPAddr.new(ip).public_send(predicate)
      rescue IPAddr::InvalidAddressError
        false
      end
      errors.add(:value, "#{key} contains an invalid IP address") unless valid
    end

    def validate_mandatory_param(list, params)
      keys = list.nil? || list.empty? ? [] : list.split(',', -1)
      if keys.empty? || keys.any?(&:empty?) || keys.uniq.length != keys.length
        errors.add(:value, 'mandatory must list unique non-empty keys')
      elsif keys.any? { |k| key_error(k) }
        errors.add(:value, 'mandatory contains an invalid key')
      elsif keys.include?('mandatory')
        errors.add(:value, 'mandatory must not include itself')
      elsif keys.any? { |k| !params.key?(k) }
        errors.add(:value, 'mandatory references a key that is not present')
      end
    end
  end
end
