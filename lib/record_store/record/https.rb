module RecordStore
  class Record::HTTPS < Record
    attr_accessor :svc_priority, :target, :params

    # Presentation form of the SvcParams (RFC 9460 §2.1), e.g.
    #   alpn="h3,h2" ipv4hint=192.0.2.1 ech=AEX...==
    # Permissive on purpose: a whitespace-separated list of `key` or `key=value`
    # tokens, where the value is either a double-quoted string or a bare token
    # (which may contain commas, dots, colons or base64 padding such as `=`).
    SVC_PARAMS_REGEX = /\A[a-z0-9-]+(=("[^"]*"|[^\s"]+))?(\s+[a-z0-9-]+(=("[^"]*"|[^\s"]+))?)*\z/i

    validates :svc_priority, presence: true, numericality: {
      only_integer: true,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 65535,
    }
    validates :target, presence: true
    validate :validate_target
    validate :validate_params

    def initialize(record)
      super

      @svc_priority = record.fetch(:svc_priority)
      @target = record.fetch(:target)
      @params = (record.fetch(:params, '') || '').to_s.strip
    end

    def rdata
      {
        svc_priority: svc_priority,
        target: target,
        params: params,
      }
    end

    def rdata_txt
      txt = "#{svc_priority} #{target}"
      txt += " #{params}" unless params.empty?
      txt
    end

    private

    # SvcPriority 0 is AliasMode (RFC 9460 §2.4.2); any other value is ServiceMode.
    def alias_mode?
      svc_priority.to_i.zero?
    end

    def validate_target
      return if target.nil?
      return if target == '.'
      return if target.match?(Record::CNAME_REGEX)

      errors.add(:target, 'must be "." or a fully qualified domain name')
    end

    def validate_params
      if alias_mode?
        errors.add(:params, 'must be empty in AliasMode (svc_priority 0)') unless params.empty?
      elsif !params.empty? && !params.match?(SVC_PARAMS_REGEX)
        errors.add(:params, 'is not a valid SvcParams list')
      end
    end
  end
end
