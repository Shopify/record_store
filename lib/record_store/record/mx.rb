module RecordStore
  class Record::MX < Record
    attr_accessor :exchange, :preference

    validates :preference, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, presence: true
    validates :exchange, presence: true, format: { with: Record::FQDN_REGEX, message: 'is not a fully qualified domain name' }

    def initialize(record)
      super
      @exchange = Record.ensure_ends_with_dot(record.fetch(:exchange))
      @preference = Integer(record.fetch(:preference))
    end

    def rdata
      {
        preference: preference,
        exchange: exchange
      }
    end

    def rdata_txt
      "#{preference} #{exchange}"
    end
  end
end
