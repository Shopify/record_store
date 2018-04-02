module RecordStore
  class Record::TXT < Record
    attr_accessor :txtdata

    validates :txtdata, presence: true, length: { maximum: 255 }
    validate :escaped_semicolons

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
      super
      @txtdata = record.fetch(:txtdata)
    end

    def rdata
      { txtdata: txtdata }
    end

    def rdata_txt
      Record::TXT.quote(txtdata)
    end

    private

    def escaped_semicolons
      if txtdata =~ /([^\\]|\A);/
        errors.add(:txtdata, 'has unescaped semicolons (See RFC 1035).')
      end
    end
  end
end
