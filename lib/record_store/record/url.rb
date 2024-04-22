module RecordStore
  class Record::URL < Record
    attr_accessor :content

    def initialize(record)
      super
      @content = record.fetch(:content)
    end

    def rdata
      { content: content }
    end

    def rdata_txt
      "#{fqdn} #{content} #{ttl}"
    end
  end
end
