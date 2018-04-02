module RecordStore
  class Record::SPF < Record::TXT
    def initialize(record)
      STDERR.puts "SPF record type is deprecated (See RFC 7208 Section 14.1)"
      super
    end
  end
end
