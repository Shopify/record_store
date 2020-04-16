require 'test_helper'

class RecordTest < Minitest::Test
  RECORD_FIXTURES = {
    alias_rr: Record::ALIAS.new(fqdn: 'dns-test.shopify.io.', alias: 'dns-test.herokuapp.com.', ttl: 60),
    caa: Record::CAA.new(fqdn: 'cname.dns-test.shopify.io.', flags: 0, tag: 'issue', value: 'digicert.com', ttl: 1800),
    cname: Record::CNAME.new(fqdn: 'cname.dns-test.shopify.io.', cname: 'dns-test.shopify.io.', ttl: 60),
    txt: Record::TXT.new(fqdn: 'txt.dns-test.shopify.io.', txtdata: 'Hello, world!', ttl: 60),
    spf: Record::SPF.new(fqdn: 'dns-test.shopify.io.', txtdata: 'v=spf1 -all', ttl: 3600),
    ns: Record::NS.new(fqdn: 'dns-test.shopify.io.', nsdname: 'ns1.dynect.net.', ttl: 3600),
    a: Record::A.new(fqdn: 'test.dns-test.shopify.io.', address: '10.11.12.13', ttl: 600),
    aaaa: Record::AAAA.new(
      fqdn: 'aaaa.dns-test.shopify.io.',
      address: '2001:0db8:85a3:0000:0000:EA75:1337:BEEF',
      ttl: 60
    ),
    mx: Record::MX.new(
      fqdn: 'mx.dns-test.shopify.io.',
      exchange: 'mail-server.example.com.',
      preference: 10,
      ttl: 60
    ),
    ptr: Record::PTR.new(
      fqdn: '4.0.41.198.in-addr.arpa',
      ttl: 3600,
      ptrdname: 'a.root-servers.net.'
    ),
    srv: Record::SRV.new(
      fqdn: '_service._TCP.srv.dns-test.shopify.io.',
      priority: 10,
      weight: 47,
      port: 80,
      target: 'target-srv.dns-test.shopify.io.',
      ttl: 60
    ),
    sshfp: Record::SSHFP.new(
      fqdn: 'dns-test.shopify.io',
      ttl: 3600,
      algorithm: Record::SSHFP::Algorithms::ED25519,
      fptype: Record::SSHFP::FingerprintTypes::SHA_256,
      fingerprint: '4e0ebbeac8d2e4e73af888b20e2243e5a2a08bad6476c832c985e54b21eff4a3',
    ),
  }

  def test_build_from_yaml_definition
    yaml_snippet = <<-YAML
      type: A
      fqdn: www.example.com.
      address: 1.2.3.4
      ttl: 5 # TTL times are in seconds
    YAML

    record = Record.build_from_yaml_definition(YAML.load(yaml_snippet).symbolize_keys)

    assert_kind_of(Record::A, record)
    assert_equal('www.example.com.', record.fqdn)
    assert_equal('1.2.3.4', record.address)
    assert_equal(5, record.ttl)
  end

  def test_downcases_fqdn
    yaml_snippet = <<-YAML
      type: TXT
      fqdn: LowerCase.example.com.
      txtdata: Value=MixedCase
      ttl: 5 # TTL times are in seconds
    YAML

    record = Record.build_from_yaml_definition(YAML.load(yaml_snippet).symbolize_keys)

    assert_kind_of(Record::TXT, record)
    assert_equal('lowercase.example.com.', record.fqdn)
  end

  def test_validates_txt
    assert_predicate(Record::TXT.new(fqdn: "_dmarc.example.com.", ttl: 600, txtdata: 'whatever'), :valid?)
    assert_predicate(Record::A.new(fqdn: "example.com.", ttl: 600, address: '10.11.12.13'), :valid?)
    assert_predicate(Record::A.new(fqdn: "example.com", ttl: 600, address: '10.11.12.13'), :valid?)

    assert_predicate(Record::A.new(fqdn: ('a' * 63) + ".com.", ttl: 600, address: '10.11.12.13'), :valid?)
    refute_predicate(Record::A.new(fqdn: ('a' * 64) + ".com.", ttl: 600, address: '10.11.12.13'), :valid?)

    assert_predicate(Record::A.new(fqdn: ("a." * 125) + "com.", ttl: 600, address: '10.11.12.13'), :valid?) # below 254
    refute_predicate(Record::A.new(fqdn: ("a." * 126) + "com.", ttl: 600, address: '10.11.12.13'), :valid?) # over 254
  end

  def test_validates_txt_length
    default_txt = { fqdn: "example.com.", ttl: 600 }

    assert_predicate(Record::TXT.new(default_txt.merge(txtdata: ("a" * 255))), :valid?)

    refute_predicate(Record::TXT.new(default_txt.merge(txtdata: ('"aa" ' * 5000))), :valid?)
  end

  def test_validates_escaped_txtdata
    default_txt = { fqdn: "example.com.", ttl: 600 }

    assert_predicate(Record::TXT.new(default_txt.merge(txtdata: 'asdf\;asdf')), :valid?)
    assert_predicate(Record::TXT.new(default_txt.merge(txtdata: '\;asdf')), :valid?)
    assert_predicate(Record::TXT.new(default_txt.merge(txtdata: 'asdf\;')), :valid?)

    refute_predicate(Record::TXT.new(default_txt.merge(txtdata: 'asdf;asdf')), :valid?)
    refute_predicate(Record::TXT.new(default_txt.merge(txtdata: ';asdf')), :valid?)
    refute_predicate(Record::TXT.new(default_txt.merge(txtdata: 'asdf;')), :valid?)
    refute_predicate(Record::TXT.new(default_txt.merge(txtdata: '\;asdf;')), :valid?)
  end

  def test_validates_ttl
    assert_predicate(Record::A.new(fqdn: 'example.com.', ttl: 600, address: '10.11.12.13'), :valid?)
    refute_predicate(Record::A.new(fqdn: 'example.com.', ttl: -1, address: '10.11.12.13'), :valid?)
    refute_predicate(Record::A.new(fqdn: 'example.com.', ttl: 2**32, address: '10.11.12.13'), :valid?)
  end

  def test_validates_caa
    assert_predicate(Record::CAA.new(
      fqdn: 'example.com.',
      flags: 0, tag: 'issue',
      value: 'digicert.com',
      ttl: 1800
    ), :valid?)
    assert_predicate(Record::CAA.new(
      fqdn: 'example.com.',
      flags: 255,
      tag: 'issue',
      value: 'digicert.com',
      ttl: 1800
    ), :valid?)
    assert_predicate(Record::CAA.new(
      fqdn: 'example.com.',
      flags: 0,
      tag: 'issuewild',
      value: 'digicert.com',
      ttl: 1800
    ), :valid?)
    assert_predicate(Record::CAA.new(
      fqdn: 'example.com.',
      flags: 0,
      tag: 'issuewild',
      value: 'Foobar.com',
      ttl: 1800
    ), :valid?)
    assert_predicate(Record::CAA.new(
      fqdn: 'example.com.',
      flags: 0,
      tag: 'iodef',
      value: 'http://example.com/iodef',
      ttl: 1800
    ), :valid?)
    assert_predicate(Record::CAA.new(
      fqdn: 'example.com.',
      flags: 0,
      tag: 'iodef',
      value: 'https://example.com/iodef',
      ttl: 1800
    ), :valid?)
    assert_predicate(Record::CAA.new(
      fqdn: 'example.com.',
      flags: 0,
      tag: 'iodef',
      value: 'mailto:iodef@example.com',
      ttl: 1800
    ), :valid?)

    refute_predicate(Record::CAA.new(
      fqdn: 'example.com.',
      flags: -1,
      tag: 'issue',
      value: 'digicert.com',
      ttl: 1800
    ), :valid?)
    refute_predicate(Record::CAA.new(
      fqdn: 'example.com.',
      flags: 256,
      tag: 'issue',
      value: 'digicert.com',
      ttl: 1800
    ), :valid?)
    refute_predicate(Record::CAA.new(
      fqdn: 'example.com.',
      flags: 0,
      tag: 'blargh',
      value: 'digicert.com',
      ttl: 1800
    ), :valid?)
    refute_predicate(Record::CAA.new(
      fqdn: 'example.com.',
      flags: 0,
      tag: 'iodef',
      value: 'mailto:invalid',
      ttl: 1800
    ), :valid?)
    refute_predicate(Record::CAA.new(
      fqdn: 'example.com.',
      flags: 0,
      tag: 'iodef',
      value: 'iodef@example.com',
      ttl: 1800
    ), :valid?)
  end

  def test_validates_cname
    assert_predicate(Record::CNAME.new(fqdn: 'example.com', ttl: 3600, cname: 'example2.com'), :valid?)
    assert_predicate(Record::CNAME.new(fqdn: 'example.com', ttl: 3600, cname: 'example-2.com'), :valid?)
    assert_predicate(Record::CNAME.new(fqdn: 'example.com', ttl: 3600, cname: 'example--2.com'), :valid?)
    assert_predicate(Record::CNAME.new(fqdn: 'example.com', ttl: 3600, cname: '_example.com'), :valid?)
    refute_predicate(Record::CNAME.new(fqdn: 'samedomain.com', ttl: 3600, cname: 'samedomain.com'), :valid?)
    refute_predicate(Record::CNAME.new(fqdn: 'example.com', ttl: 3600, cname: 'example---2.com'), :valid?)
    refute_predicate(Record::CNAME.new(fqdn: 'example.com', ttl: 3600, cname: '--2.com'), :valid?)
  end

  def test_validates_alias
    assert_predicate(Record::ALIAS.new(fqdn: 'example.com', ttl: 3600, alias: 'example2.com'), :valid?)
    refute_predicate(Record::ALIAS.new(fqdn: 'samedomain.com', ttl: 3600, alias: 'samedomain.com'), :valid?)
  end

  def test_to_hash
    record = Record::NS.new(fqdn: 'example.com', ttl: 600, nsdname: 'blah.example.com')
    hash = record.to_hash

    assert_equal('NS', hash[:type])
    assert_equal('example.com.', hash[:fqdn])
    assert_equal('blah.example.com.', hash[:nsdname])
    assert_equal(600, hash[:ttl])
  end

  def test_to_json
    record = Record::TXT.new(fqdn: 'example.com.', ttl: 600, txtdata: 'foo')
    hash = record.to_json

    assert_equal('foo', hash[:rdata][:txtdata])
    assert_equal(600, hash[:ttl])
  end

  def test_record_type
    assert_equal('TXT', Record::TXT.new(fqdn: 'example.com.', ttl: 600, txtdata: 'foo').type)
    assert_equal('CNAME', Record::CNAME.new(fqdn: 'example.com.', ttl: 600, cname: 'www.example.com').type)
  end

  def test_rdata_txt_returns_zonefile_compliant_formatting
    assert_equal('10.11.12.13', RECORD_FIXTURES[:a].rdata_txt)
    assert_equal('2001:0db8:85a3:0000:0000:EA75:1337:BEEF', RECORD_FIXTURES[:aaaa].rdata_txt)
    assert_equal('dns-test.herokuapp.com.', RECORD_FIXTURES[:alias_rr].rdata_txt)
    assert_equal('0 issue "digicert.com"', RECORD_FIXTURES[:caa].rdata_txt)
    assert_equal('dns-test.shopify.io.', RECORD_FIXTURES[:cname].rdata_txt)
    assert_equal('10 mail-server.example.com.', RECORD_FIXTURES[:mx].rdata_txt)
    assert_equal('ns1.dynect.net.', RECORD_FIXTURES[:ns].rdata_txt)
    assert_equal('10 47 80 target-srv.dns-test.shopify.io.', RECORD_FIXTURES[:srv].rdata_txt)
    assert_equal('"Hello, world!"', RECORD_FIXTURES[:txt].rdata_txt)
    assert_equal('"v=spf1 -all"', RECORD_FIXTURES[:spf].rdata_txt)
    assert_equal(
      '4 2 4e0ebbeac8d2e4e73af888b20e2243e5a2a08bad6476c832c985e54b21eff4a3',
      RECORD_FIXTURES[:sshfp].rdata_txt
    )
    assert_equal('a.root-servers.net.', RECORD_FIXTURES[:ptr].rdata_txt)
  end

  def test_consistent_print_formatting
    assert_equal('[ARecord] test.dns-test.shopify.io. 600 IN A 10.11.12.13', RECORD_FIXTURES[:a].to_s)
    assert_equal('[AAAARecord] aaaa.dns-test.shopify.io. 60 IN AAAA '\
                 '2001:0db8:85a3:0000:0000:EA75:1337:BEEF', RECORD_FIXTURES[:aaaa].to_s)
    assert_equal('[ALIASRecord] dns-test.shopify.io. 60 IN ALIAS '\
                 'dns-test.herokuapp.com.', RECORD_FIXTURES[:alias_rr].to_s)
    assert_equal('[CAARecord] cname.dns-test.shopify.io. 1800 IN CAA 0 issue '\
                 '"digicert.com"', RECORD_FIXTURES[:caa].to_s)
    assert_equal('[CNAMERecord] cname.dns-test.shopify.io. 60 IN CNAME '\
                 'dns-test.shopify.io.', RECORD_FIXTURES[:cname].to_s)
    assert_equal('[MXRecord] mx.dns-test.shopify.io. 60 IN MX 10 mail-server.example.com.', RECORD_FIXTURES[:mx].to_s)
    assert_equal('[NSRecord] dns-test.shopify.io. 3600 IN NS ns1.dynect.net.', RECORD_FIXTURES[:ns].to_s)
    assert_equal('[SRVRecord] _service._tcp.srv.dns-test.shopify.io. 60 IN SRV 10 47 80 '\
                 'target-srv.dns-test.shopify.io.', RECORD_FIXTURES[:srv].to_s)
    assert_equal('[TXTRecord] txt.dns-test.shopify.io. 60 IN TXT "Hello, world!"', RECORD_FIXTURES[:txt].to_s)
    assert_equal('[SPFRecord] dns-test.shopify.io. 3600 IN SPF "v=spf1 -all"', RECORD_FIXTURES[:spf].to_s)
    assert_equal(
      '[SSHFPRecord] dns-test.shopify.io. 3600 IN SSHFP 4 2 '\
      '4e0ebbeac8d2e4e73af888b20e2243e5a2a08bad6476c832c985e54b21eff4a3',
      RECORD_FIXTURES[:sshfp].to_s
    )
  end

  def test_txt_record_with_embedded_whitespace
    record = Record::TXT.new(fqdn: 'example.com.', ttl: 600, txtdata: 'embedded whitespace')

    assert_predicate(record, :valid?)
    assert_equal('embedded whitespace', record.txtdata)
    assert_equal('"embedded whitespace"', record.rdata_txt)
    assert_equal('[TXTRecord] example.com. 600 IN TXT "embedded whitespace"', record.to_s)
  end

  def test_txt_record_with_embedded_quotes
    record = Record::TXT.new(fqdn: 'example.com.', ttl: 600, txtdata: 'embedded "quotes"')

    assert_predicate(record, :valid?)
    assert_equal('embedded "quotes"', record.txtdata)
    assert_equal('"embedded \"quotes\""', record.rdata_txt)
    assert_equal('[TXTRecord] example.com. 600 IN TXT "embedded \"quotes\""', record.to_s)
  end

  def test_escape_quotes
    assert_equal('text with \"quotes\"', Record.escape('text with "quotes"'))
  end

  def test_quote_value
    assert_equal('"text with \"quotes\""', Record.quote('text with "quotes"'))
  end

  def test_unescape_quotes
    assert_equal('text with "quotes"', Record.unescape('text with \"quotes\"'))
  end

  def test_unquote_value
    assert_equal('text with "quotes"', Record.unquote('"text with \"quotes\""'))
  end

  def test_unlong_quote_value
    assert_equal('text with "quotes"', Record.unlong_quote('"text with \"quotes\""'))
    assert_equal(("a" * 265), Record.unlong_quote('"' + ("a" * 255) + '" "' + ("a" * 10) + '"'))
    assert_equal(("a" * 600), Record.unlong_quote('"' + ("a" * 255) + '" ' \
                  + '"' + ("a" * 255) + '" ' + '"' + ("a" * 90)))
    assert_equal(("a" * 600), Record.unlong_quote(Record.quote(("a" * 600))))
    assert_equal(("a" * 600), Record.unlong_quote("a" * 600))
  end

  def test_long_quote_value
    assert_equal('short text with "quotes"', Record.long_quote('short text with "quotes"'))
    assert_equal(Record.long_quote("a" * 265), '"' + ("a" * 255) + '" "' + ("a" * 10) + '"')
    assert_equal(Record.long_quote("a" * 600), '"' + ("a" * 255) + '" "' \
                  + ("a" * 255) + '" "' + ("a" * 90) + '"')
  end

  def test_valid_sshfp_record
    assert_predicate(Record::SSHFP.new(
      fqdn: 'dns-test.shopify.io',
      ttl: 3600,
      algorithm: Record::SSHFP::Algorithms::ED25519,
      fptype: Record::SSHFP::FingerprintTypes::SHA_256,
      fingerprint: '4e0ebbeac8d2e4e73af888b20e2243e5a2a08bad6476c832c985e54b21eff4a3',
    ), :valid?)
  end

  def test_unknown_sshfp_algorithm
    refute_predicate(Record::SSHFP.new(
      fqdn: 'dns-test.shopify.io',
      ttl: 3600,
      algorithm: 999,
      fptype: Record::SSHFP::FingerprintTypes::SHA_256,
      fingerprint: '4e0ebbeac8d2e4e73af888b20e2243e5a2a08bad6476c832c985e54b21eff4a3',
    ), :valid?)
  end

  def test_unknown_sshfp_fingerprint_type
    refute_predicate(Record::SSHFP.new(
      fqdn: 'dns-test.shopify.io',
      ttl: 3600,
      algorithm: Record::SSHFP::Algorithms::ED25519,
      fptype: 999,
      fingerprint: '4e0ebbeac8d2e4e73af888b20e2243e5a2a08bad6476c832c985e54b21eff4a3',
    ), :valid?)
  end

  def test_non_hexadecimal_fingerprints
    refute_predicate(Record::SSHFP.new(
      fqdn: 'dns-test.shopify.io',
      ttl: 3600,
      algorithm: Record::SSHFP::Algorithms::ED25519,
      fptype: Record::SSHFP::FingerprintTypes::SHA_256,
      fingerprint: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    ), :valid?)
  end

  def test_spf_is_deprecated
    Record::SPF.new(fqdn: 'dns-test.shopify.io.', txtdata: 'v=spf1 -all', ttl: 3600)
    assert_includes($stderr.string, "SPF record type is deprecated (See RFC 7208 Section 14.1)")
  end

  def test_valid_ptr_record
    assert_predicate(Record::PTR.new(
      fqdn: '4.0.41.198.in-addr.arpa',
      ttl: 3600,
      ptrdname: 'a.root-servers.net.'
    ), :valid?)
  end

  def test_invalid_when_fqdn_is_outside_arpa_zone
    refute_predicate(Record::PTR.new(
      fqdn: 'example.com',
      ttl: 3600,
      ptrdname: 'a.root-servers.net.'
    ), :valid?)
  end

  def test_invalid_when_no_octets
    refute_predicate(Record::PTR.new(
      fqdn: 'in-addr.arpa',
      ttl: 3600,
      ptrdname: 'a.root-servers.net.'
    ), :valid?)
  end

  def test_valid_when_between_one_to_four_octets
    assert_predicate(Record::PTR.new(
      fqdn: '111.22.3.in-addr.arpa',
      ttl: 3600,
      ptrdname: 'a.root-servers.net.'
    ), :valid?)
  end

  def test_invalid_when_over_four_octets
    refute_predicate(Record::PTR.new(
      fqdn: '1.2.3.4.5.in-addr.arpa',
      ttl: 3600,
      ptrdname: 'a.root-servers.net.'
    ), :valid?)
  end

  def test_invalid_when_octet_out_of_range
    refute_predicate(Record::PTR.new(
      fqdn: '256.in-addr.arpa',
      ttl: 3600,
      ptrdname: 'a.root-servers.net.'
    ), :valid?)
  end
end
