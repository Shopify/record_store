module RecordStore
  class Record::SSHFP < Record
    attr_accessor :algorithm, :fptype, :fingerprint

    # https://www.iana.org/assignments/dns-sshfp-rr-parameters/dns-sshfp-rr-parameters.xhtml
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

    FINGERPRINT_REGEX = /\A[[:xdigit:]]+\z/

    class << self
      private

      def constants_defined_in(mod)
        mod.constants(false).map(&mod.method(:const_get))
      end
    end

    validates :algorithm, presence: true, inclusion: { in: constants_defined_in(Algorithms) }
    validates :fingerprint, presence: true, format: { with: FINGERPRINT_REGEX }
    validates :fptype, presence: true, inclusion: { in: constants_defined_in(FingerprintTypes) }

    def initialize(record)
      super

      @algorithm = record.fetch(:algorithm)
      @fptype = record.fetch(:fptype)
      @fingerprint = record.fetch(:fingerprint)
    end

    def rdata
      {
        algorithm: algorithm,
        fingerprint: fingerprint,
        fptype: fptype,
      }
    end

    def rdata_txt
      "#{algorithm} #{fptype} #{fingerprint}"
    end
  end
end
