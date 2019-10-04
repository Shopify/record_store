module RecordStore
  class Record::A < Record
    attr_accessor :address

    validates_presence_of :address
    validate :valid_address?

    def initialize(record)
      super
      @address = record.fetch(:address)
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
  end
end
