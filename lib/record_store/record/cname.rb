module RecordStore
  class Record::CNAME < Record
    attr_accessor :cname

    validates :cname, presence: true, format:
      {
        with: Record::CNAME_REGEX,
        message: 'is not a fully qualified domain name',
      }
    validate :validate_circular_reference

    def initialize(record)
      super
      @cname = Record.ensure_ends_with_dot(record.fetch(:cname))
    end

    def rdata
      { cname: cname }
    end

    def rdata_txt
      cname
    end

    def validate_circular_reference
      errors.add(:fqdn, 'A CNAME should not point to itself') if fqdn == cname
    end
  end
end
