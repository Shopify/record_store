# frozen_string_literal: true

module RecordStore
  class Zone
    class Config
      class IgnorePattern
        MATCH_TYPE_FIELD = 'match'
        MATCH_TYPE_REGEX = 'regex'
        MATCH_TYPE_EXACT = 'exact'

        def initialize(orig_hash)
          @orig_hash = orig_hash
        end

        def ignore?(record)
          all_pairs.all? do |(key, value)|
            record.respond_to?(key) && value_matches?(value, record.send(key))
          end
        end

        def to_hash
          @orig_hash
        end

        private

        def all_pairs
          to_hash.reject { |key| key == MATCH_TYPE_FIELD }
        end

        def value_matches?(ignore_pattern_value, record_value)
          return record_value.match?(ignore_pattern_value) if regex?
          return record_value == ignore_pattern_value if exact?

          false
        end

        def regex?
          to_hash[MATCH_TYPE_FIELD] == MATCH_TYPE_REGEX
        end

        def exact?
          to_hash.fetch(MATCH_TYPE_FIELD, MATCH_TYPE_EXACT) == MATCH_TYPE_EXACT
        end
      end
    end
  end
end
