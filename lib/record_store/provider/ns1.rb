require_relative 'ns1/client'
require_relative 'ns1/patch_api_header'

module RecordStore
  class Provider::NS1 < Provider
    class ApiAnswer
      class << self
        def from_full_api_answer(type:, record_id:, answer:)
          ApiAnswer.new(type: type, record_id: record_id, rrdata: answer['answer'])
        end

        def from_short_api_answer(type:, record_id:, answer:)
          rrdata_fields = case type
          when 'SPF', 'TXT'
            [answer]
          when 'SRV'
            priority, weight, port, host = answer.split
            [priority.to_i, weight.to_i, port.to_i, Record.ensure_ends_with_dot(host)]
          else
            answer.split
          end

          ApiAnswer.new(type: type, record_id: record_id, rrdata: rrdata_fields)
        end
      end

      attr_accessor :type, :record_id, :rrdata

      def initialize(type:, record_id:, rrdata:)
        @type = type
        @record_id = record_id
        @rrdata = rrdata
      end

      def rrdata_string
        rrdata.join(' ')
      end

      def id
        [record_id, type, *rrdata]
      end
    end

    class << self
      def record_types
        super | Set.new(%w(PTR))
      end

      def client
        Provider::NS1::Client.new(api_key: secrets['api_key'])
      end

      # Downloads all the records from the provider.
      #
      # Returns: an array of `Record` for each record in the provider's zone
      def retrieve_current_records(zone:, stdout: $stdout)
        records_for_zone(zone)
          .flat_map { |short_record| build_from_api(short_record) }
          .compact
      end

      # Returns an array of the zones managed by provider as strings
      def zones
        retry_on_connection_errors do
          client.zones.map { |zone| zone['zone'] }
        end
      end

      private

      # Fetches simplified records for the provided zone
      def records_for_zone(zone)
        retry_on_connection_errors do
          client.zone(zone)['records']
        end
      end

      # Creates a new record to the zone. It is expected this call modifies external state.
      #
      # Arguments:
      # record - a kind of `Record`
      def add(record, zone)
        new_answers = [{ answer: build_api_answer_from_record(record) }]

        record_fqdn = record.fqdn.sub(/\.$/, '')

        existing_record = client.record(
          zone: zone,
          fqdn: record_fqdn,
          type: record.type,
        )

        if existing_record.nil?
          client.create_record(
            zone: zone,
            fqdn: record_fqdn,
            type: record.type,
            params: {
              answers: new_answers,
              ttl: record.ttl,
              use_client_subnet: false, # only required for filter chains that are not supported by record_store
            },
          )
          return
        end

        existing_answers = existing_record['answers'].map { |answer| symbolize_keys(answer) }
        client.modify_record(
          zone: zone,
          fqdn: record_fqdn,
          type: record.type,
          params: { answers: existing_answers + new_answers, ttl: record.ttl },
        )
      end

      # Deletes an existing record from the zone. It is expected this call modifies external state.
      #
      # Arguments:
      # record - a kind of `Record`
      def remove(record, zone)
        record_fqdn = record.fqdn.sub(/\.$/, '')

        existing_record = client.record(
          zone: zone,
          fqdn: record_fqdn,
          type: record.type,
        )
        return if existing_record.nil?

        pruned_answers = existing_record['answers']
          .map { |answer| symbolize_keys(answer) }
          .reject { |answer| answer[:answer] == build_api_answer_from_record(record) }

        if pruned_answers.empty?
          client.delete_record(
            zone: zone,
            fqdn: record_fqdn,
            type: record.type,
          )
          return
        end

        client.modify_record(
          zone: zone,
          fqdn: record_fqdn,
          type: record.type,
          params: { answers: pruned_answers },
        )
      end

      # Updates an existing record in the zone. It is expected this call modifies external state.
      #
      # Arguments:
      # id - provider specific ID of record to update
      # record - a kind of `Record` which the record with `id` should be updated to
      def update(id, record, zone)
        record_fqdn = record.fqdn.sub(/\.$/, '')

        existing_record = client.record(
          zone: zone,
          fqdn: record_fqdn,
          type: record.type,
          must_exist: true,
        )

        # Identify the answer in this record with the matching ID, and update it
        updated = false
        existing_record['answers'].each do |existing_answer|
          existing_answer_id = ApiAnswer.from_full_api_answer(
            record_id: existing_record['id'],
            type: existing_record['type'],
            answer: existing_answer,
          ).id

          next if existing_answer_id != id

          updated = true
          existing_answer['answer'] = build_api_answer_from_record(record)
        end

        unless updated
          error = +'while trying to update a record, could not find answer with fqdn: '
          error << "#{record.fqdn}, type; #{record.type}, id: #{id}"
          raise RecordStore::Provider::Error, error
        end

        client.modify_record(
          zone: zone,
          fqdn: record_fqdn,
          type: record.type,
          params: { answers: existing_record['answers'], ttl: record.ttl },
        )
      end

      def build_from_api(api_record)
        fqdn = Record.ensure_ends_with_dot(api_record['domain'])

        record_type = api_record['type']
        return if record_type == 'SOA'

        answers = api_record['short_answers'].map do |raw_answer|
          ApiAnswer.from_short_api_answer(
            record_id: api_record['id'],
            type: api_record['type'],
            answer: raw_answer,
          )
        end

        answers.map do |answer|
          record = {
            ttl: api_record['ttl'],
            fqdn: fqdn.downcase,
            record_id: answer.id,
          }

          case record_type
          when 'A', 'AAAA'
            record.merge!(address: answer.rrdata_string)
          when 'ALIAS'
            record.merge!(alias: answer.rrdata_string)
          when 'CAA'
            flags, tag, value = answer.rrdata

            record.merge!(
              flags: flags.to_i,
              tag: tag,
              value: Record.unquote(value),
            )
          when 'CNAME'
            record.merge!(cname: answer.rrdata_string)
          when 'MX'

            preference, exchange = answer.rrdata

            record.merge!(
              preference: preference.to_i,
              exchange: exchange,
            )
          when 'NS'
            record.merge!(nsdname: answer.rrdata_string)
          when 'PTR'
            record.merge!(ptrdname: answer.rrdata_string)
          when 'SPF', 'TXT'
            record.merge!(txtdata: answer.rrdata_string.gsub(';', '\;'))
          when 'SRV'
            priority, weight, port, host = answer.rrdata

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
          [record.txtdata.gsub('\;', ';')]
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
    end
  end
end
