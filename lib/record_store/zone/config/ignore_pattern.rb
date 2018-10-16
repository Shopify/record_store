module RecordStore
  class Zone
    class Config
      class IgnorePattern
        def initialize(orig_hash)
          @orig_hash = orig_hash
        end

        def should_ignore?(record)
          all_pairs.all?{|(key, value)| record.respond_to?(key) && value_matches?(value, record.send(key))}
        end

        def to_hash
          orig_hash
        end

        private

        attr_accessor :orig_hash

        def all_pairs
          orig_hash.reject{|key, value| key === 'match'}
        end

        def value_matches?(ignore_pattern_value, record_value)
          return record_value.match?(ignore_pattern_value) if is_regex?
          return record_value === ignore_pattern_value if is_exact?
          false
        end

        def is_regex?
          orig_hash['match'] === 'regex'
        end

        def is_exact?
          !orig_hash.key?('match') || (orig_hash['match'] === 'exact')
        end
      end
    end
  end
end
