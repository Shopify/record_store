module RecordStore
  class Record::PTR < Record
    attr_accessor :ptrdname

    def initialize(record)
      super

      @ptrdname = record.fetch(:ptrdname)
    end
  end
end
