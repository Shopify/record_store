module RecordStore
  class Record::A < Record
    attr_reader :address

    validates_presence_of :address
    validate :valid_address?

    def initialize(record)
      super
      self.address = record.fetch(:address)
    end

    def address=(value)
      @address = normalize_address(value)
    end

    def rdata
      { address: address }
    end

    def rdata_txt
      address
    end

    private

    def valid_address?
      ip = IPAddr.new(address)
      errors.add(:address, 'is not an IPv4 address') unless ip.ipv4?
    rescue IPAddr::InvalidAddressError
      errors.add(:address, 'is invalid')
    end

    def normalize_address(value)
      IPAddr.new(value).to_s
    rescue IPAddr::InvalidAddressError
      value
    end
  end
end
