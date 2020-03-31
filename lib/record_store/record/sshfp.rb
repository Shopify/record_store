module RecordStore
  class Record::SSHFP < Record
    attr_accessor :algorithm, :fptype, :fingerprint

    # https://www.iana.org/assignments/dns-sshfp-rr-parameters/dns-sshfp-rr-parameters.xhtml
    #
    module Algorithms
      RESERVED = 0
      RSA = 1
      DSA = 2
      ECDSA = 3
      ED25519 = 4
      UNASSIGNED = 5
      ED448 = 6
    end

    module FingerprintTypes
      RESERVED = 0
      SHA_1 = 1
      SHA_256 = 2
    end

    FINGERPRINT_REGEX = /\A[[:xdigit:]]+\Z/

    validates :algorithm,
      presence: true,
      inclusion: { in: Algorithms.constants(false).map(&Algorithms.method(:const_get)) }
    validates :fptype,
      presence: true,
      inclusion: { in: FingerprintTypes.constants(false).map(&FingerprintTypes.method(:const_get)) }
    validates :fingerprint, presence: true, format: { with: FINGERPRINT_REGEX }

    def initialize(record)
      super

      @algorithm = record.fetch(:algorithm)
      @fptype = record.fetch(:fptype)
      @fingerprint = record.fetch(:fingerprint)
    end
  end
end
