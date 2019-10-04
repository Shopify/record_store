module RecordStore
  class Record
    FQDN_REGEX  = /\A(\*\.)?([a-z0-9_]+(-[a-z0-9]+)*\._?)+[a-z]{2,}\.\Z/i
    CNAME_REGEX = /\A(\*\.)?([a-z0-9_]+((-|--)?[a-z0-9]+)*\._?)+[a-z]{2,}\.\Z/i

    include ActiveModel::Validations

    attr_accessor :fqdn, :ttl, :id

    validates :ttl, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 2147483647 }
    validates :fqdn, format: { with: Record::FQDN_REGEX }, length: { maximum: 254 }
    validate :validate_label_length

    class << self
      def escape(value)
        value.gsub('"', '\"')
      end

      def quote(value)
        %("#{escape(value)}")
      end

      def unescape(value)
        value.gsub('\"', '"')
      end

      def unquote(value)
        unescape(value.sub(/\A"(.*)"\z/, '\1'))
      end
    end

    def initialize(record)
      @fqdn = Record.ensure_ends_with_dot(record.fetch(:fqdn)).downcase
      @ttl  = record.fetch(:ttl)
      @id   = record.fetch(:record_id, nil)
    end

    def self.build_from_yaml_definition(yaml_definition)
      record_type = yaml_definition.fetch(:type)
      Record.const_get(record_type).new(yaml_definition)
    end

    def log!(logger = STDOUT)
      logger.puts to_s
    end

    def to_hash
      {
        type: type,
        fqdn: fqdn,
        ttl: ttl,
      }.merge(rdata)
    end

    def type
      self.class.name.demodulize
    end

    def ==(other)
      other.class == self.class && other.to_hash == to_hash
    end

    alias_method :eql?, :==

    def hash
      to_hash.hash
    end

    def to_json
      { ttl: ttl, rdata: rdata }
    end

    def key
      "#{type},#{fqdn}"
    end

    def rdata
      raise NotImplementedError
    end

    def rdata_txt
      raise NotImplementedError
    end

    def to_s
      "[#{type}Record] #{fqdn} #{ttl} IN #{type} #{rdata_txt}"
    end

    protected

    def validate_label_length
      unless fqdn.split('.').all? { |label| label.length <= 63 }
        errors.add(:fqdn, "A label should be at most 63 characters")
      end
    end

    def self.ensure_ends_with_dot(fqdn)
      fqdn.end_with?(".") ? fqdn : "#{fqdn}."
    end
  end
end
