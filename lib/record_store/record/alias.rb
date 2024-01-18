module RecordStore
  class Record::ALIAS < Record
    attr_accessor :alias

    validates :alias, presence: true, format:
      {
        with: Record::CNAME_REGEX,
        message: 'is not a fully qualified domain name',
      }
    validate :validate_circular_reference

    def initialize(record)
      super
      @alias = Record.ensure_ends_with_dot(record.fetch(:alias))
    end

    def rdata
      { alias: self.alias }
    end

    def rdata_txt
      self.alias
    end

    def validate_circular_reference
      errors.add(:fqdn, 'An ALIAS should not point to itself') if fqdn == @alias
    end
  end
end
