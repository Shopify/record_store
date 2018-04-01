module RecordStore
  class Record::TXT < Record
    attr_accessor :txtdata

    validates :txtdata, presence: true, length: { maximum: 255 }
    validate :escaped_semicolons

    def initialize(record)
      super
      @txtdata = record.fetch(:txtdata)
    end

    def rdata
      { txtdata: txtdata }
    end

    def rdata_txt
      %("#{txtdata.gsub('"', '\"')}")
    end

    private

    def escaped_semicolons
      if txtdata =~ /([^\\]|\A);/
        errors.add(:txtdata, 'has unescaped semicolons (See RFC 1035).')
      end
    end
  end
end
