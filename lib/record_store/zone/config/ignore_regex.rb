module RecordStore
  class Zone
    class Config
      class IgnoreRegex
        attr_accessor :orig_hash
        alias_method :to_hash, :orig_hash

        def initialize(orig_hash)
          @orig_hash = orig_hash
        end

        def should_ignore?(record)
          orig_hash.all?{|(key, value)| record.respond_to?(key) && record.send(key).match(value)}
        end
      end
    end
  end
end
