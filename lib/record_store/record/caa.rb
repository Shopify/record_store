module RecordStore
  class Record::CAA < Record
    attr_accessor :flags, :tag, :value

    LABEL_REGEX = '[a-z0-9](?:-*[a-z0-9])*'
    DOMAIN_REGEX = /\A#{LABEL_REGEX}(?:\.#{LABEL_REGEX})\z/i

    validates :flags, presence: true, numericality:
      {
        only_integer: true, greater_than_or_equal_to: 0,
        less_than_or_equal_to: 255
      }
    validates :tag, inclusion: { in: %w(issue issuewild iodef) }, presence: true
    validate :validate_uri_value, if: :iodef?
    validates :value, format: { with: DOMAIN_REGEX, message: 'is not a fully qualified domain name' }, unless: :iodef?

    def initialize(record)
      super
      @flags = Integer(record.fetch(:flags))
      @tag = record.fetch(:tag)
      @value = record.fetch(:value)
    end

    def rdata
      {
        flags: flags,
        tag: tag,
        value: value,
      }
    end

    def rdata_txt
      "#{flags} #{tag} \"#{value}\""
    end

    protected

    def iodef?
      tag == 'iodef'
    end

    def validate_uri_value
      uri = URI(value)
      return if uri.is_a?(URI::MailTo) || uri.is_a?(URI::HTTP)
      errors.add(:value, "URL scheme should be mailto, http, or https")
    rescue URI::Error
      errors.add(:value, "Value should be a valid URI")
    end
  end
end
