require_relative 'ns1/client'
require 'limiter'

module RecordStore
  class Provider::NS1 < Provider
    class Error < StandardError; end

    class << self
      include Limiter
      def client
        Provider::NS1::Client.new(api_key: secrets['api_key'])
      end

      # Downloads all the records from the provider.
      #
      # Returns: an array of `Record` for each record in the provider's zone
      def retrieve_current_records(zone:, stdout: $stdout) # rubocop:disable Lint/UnusedMethodArgument
        limiter_for_get_api
        full_api_records = records_for_zone(zone).map do |short_record|
          client.record(
            zone: zone,
            fqdn: short_record["domain"],
            type: short_record["type"],
            must_exist: true,
          )
        end

        full_api_records.map { |r| build_from_api(r) }.flatten.compact
      end

      # Returns an array of the zones managed by provider as strings
      def zones
        limiter_for_get_api
        client.zones.map { |zone| zone['zone'] }
      end

      private

      # Fetches simplified records for the provided zone
      def records_for_zone(zone)
        limiter_for_get_api
        client.zone(zone)["records"]
      end

      # Creates a new record to the zone. It is expected this call modifies external state.
      #
      # Arguments:
      # record - a kind of `Record`
      def add(record, zone)
        limiter_for_post_or_put_api
        new_answers = [{ answer: build_api_answer_from_record(record) }]

        record_fqdn = record.fqdn.sub(/\.$/, '')

        existing_record = client.record(
          zone: zone,
          fqdn: record_fqdn,
          type: record.type
        )

        if existing_record.nil?
          client.create_record(
            zone: zone,
            fqdn: record_fqdn,
            type: record.type,
            params: { answers: new_answers, ttl: record.ttl }
          )
          return
        end

        existing_answers = existing_record['answers'].map { |answer| symbolize_keys(answer) }
        client.modify_record(
          zone: zone,
          fqdn: record_fqdn,
          type: record.type,
          params: { answers: existing_answers + new_answers, ttl: record.ttl }
        )
      end

      # Deletes an existing record from the zone. It is expected this call modifies external state.
      #
      # Arguments:
      # record - a kind of `Record`
      def remove(record, zone)
        limiter_for_post_or_put_api
        record_fqdn = record.fqdn.sub(/\.$/, '')

        existing_record = client.record(
          zone: zone,
          fqdn: record_fqdn,
          type: record.type
        )
        return if existing_record.nil?

        pruned_answers = existing_record['answers']
          .map { |answer| symbolize_keys(answer) }
          .reject { |answer| answer[:answer] == build_api_answer_from_record(record) }

        if pruned_answers.empty?
          client.delete_record(
            zone: zone,
            fqdn: record_fqdn,
            type: record.type
          )
          return
        end

        client.modify_record(
          zone: zone,
          fqdn: record_fqdn,
          type: record.type,
          params: { answers: pruned_answers }
        )
      end

      # Updates an existing record in the zone. It is expected this call modifies external state.
      #
      # Arguments:
      # id - provider specific ID of record to update
      # record - a kind of `Record` which the record with `id` should be updated to
      def update(id, record, zone)
        limiter_for_post_or_put_api
        record_fqdn = record.fqdn.sub(/\.$/, '')

        existing_record = client.record(
          zone: zone,
          fqdn: record_fqdn,
          type: record.type,
          must_exist: true,
        )

        # Identify the answer in this record with the matching ID, and update it
        updated = false
        existing_record["answers"].each do |answer|
          next if answer["id"] != id
          updated = true
          answer["answer"] = build_api_answer_from_record(record)
        end

        unless updated
          error = +'while trying to update a record, could not find answer with fqdn: '
          error << "#{record.fqdn}, type; #{record.type}, id: #{id}"
          raise Error, error
        end

        client.modify_record(
          zone: zone,
          fqdn: record_fqdn,
          type: record.type,
          params: { answers: existing_record["answers"], ttl: record.ttl }
        )
      end

      def build_from_api(api_record)
        fqdn = Record.ensure_ends_with_dot(api_record["domain"])

        record_type = api_record["type"]
        return if record_type == 'SOA'

        api_record["answers"].map do |api_answer|
          answer = api_answer["answer"]
          record = {
            ttl: api_record["ttl"],
            fqdn: fqdn.downcase,
            record_id: api_answer["id"],
          }

          case record_type
          when 'A', 'AAAA'
            record.merge!(address: answer.first)
          when 'ALIAS'
            record.merge!(alias: answer.first)
          when 'CAA'
            flags, tag, value = answer

            record.merge!(
              flags: flags.to_i,
              tag: tag,
              value: Record.unquote(value),
            )
          when 'CNAME'
            record.merge!(cname: answer.first)
          when 'MX'

            preference, exchange = answer

            record.merge!(
              preference: preference.to_i,
              exchange: exchange,
            )
          when 'NS'
            record.merge!(nsdname: answer.first)
          when 'SPF', 'TXT'
            record.merge!(txtdata: Record.unlong_quote(Record.unescape(answer.first).gsub(';', '\;')))
          when 'SRV'
            priority, weight, port, host = answer

            record.merge!(
              priority: priority.to_i,
              weight: weight.to_i,
              port: port.to_i,
              target: Record.ensure_ends_with_dot(host),
            )
          end
          Record.const_get(record_type).new(record)
        end
      end

      def build_api_answer_from_record(record)
        if record.is_a?(Record::MX)
          [record.preference, record.exchange]
        elsif record.is_a?(Record::TXT) || record.is_a?(Record::SPF)
          [Record.long_quote(record.txtdata)]
        elsif record.is_a?(Record::CAA)
          [record.flags, record.tag, record.value]
        elsif record.is_a?(Record::SRV)
          [record.priority, record.weight, record.port, record.target]
        else
          [record.rdata_txt]
        end
      end

      def symbolize_keys(hash)
        hash.map { |key, value| [key.to_sym, value] }.to_h
      end

      def secrets
        super.fetch('ns1')
      end

      def limiter_ratequeue_initializing
        if @queue.nil?
          @queue = RateQueue.new(10000, interval: 3600)
        end
      end

      def limiter_for_get_api
        limiter_ratequeue_initializing
        @queue.shift
      end

      def limiter_for_post_or_put_api
        limiter_ratequeue_initializing
        # POST or PUT API is three times expensive than GET API
        3.times { @queue.shift }
      end
    end
  end
end
