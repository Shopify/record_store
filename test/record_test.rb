require 'test_helper'

class RecordTest < Minitest::Test
  def test_build_from_yaml_definition
    yaml_snippet = <<-YAML
      type: A
      fqdn: www.example.com.
      address: 1.2.3.4
      ttl: 5 # TTL times are in seconds
    YAML

    record = Record.build_from_yaml_definition(YAML.load(yaml_snippet).symbolize_keys)

    assert_kind_of Record::A, record
    assert_equal 'www.example.com.', record.fqdn
    assert_equal '1.2.3.4', record.address
    assert_equal 5, record.ttl
  end

  def test_validates_txt
    assert Record::TXT.new(fqdn: "_dmarc.example.com.", ttl: 600, txtdata: 'whatever').valid?
    assert Record::A.new(fqdn: "example.com.", ttl: 600, address: '10.11.12.13').valid?
    assert Record::A.new(fqdn: "example.com", ttl: 600, address: '10.11.12.13').valid?

    assert Record::A.new(fqdn: ('a' * 63) + ".com.", ttl: 600, address: '10.11.12.13').valid?
    refute Record::A.new(fqdn: ('a' * 64) + ".com.", ttl: 600, address: '10.11.12.13').valid?

    assert Record::A.new(fqdn: ("a." * 125) + "com.", ttl: 600, address: '10.11.12.13').valid? # below 254
    refute Record::A.new(fqdn: ("a." * 126) + "com.", ttl: 600, address: '10.11.12.13').valid? # over 254
  end

  def test_validates_escaped_txtdata
    default_txt = { fqdn: "example.com.", ttl: 600 }

    assert Record::TXT.new(default_txt.merge(txtdata: 'asdf\;asdf')).valid?
    assert Record::TXT.new(default_txt.merge(txtdata: '\;asdf')).valid?
    assert Record::TXT.new(default_txt.merge(txtdata: 'asdf\;')).valid?

    refute Record::TXT.new(default_txt.merge(txtdata: 'asdf;asdf')).valid?
    refute Record::TXT.new(default_txt.merge(txtdata: ';asdf')).valid?
    refute Record::TXT.new(default_txt.merge(txtdata: 'asdf;')).valid?
    refute Record::TXT.new(default_txt.merge(txtdata: '\;asdf;')).valid?
  end

  def test_validates_ttl
    assert Record::A.new(fqdn: 'example.com.', ttl: 600, address: '10.11.12.13').valid?
    refute Record::A.new(fqdn: 'example.com.', ttl: -1, address: '10.11.12.13').valid?
    refute Record::A.new(fqdn: 'example.com.', ttl: 2 ** 32, address: '10.11.12.13').valid?
  end

  def test_validates_cname
    assert Record::CNAME.new(fqdn: 'example.com', ttl: 3600, cname: 'example2.com').valid?
    refute Record::CNAME.new(fqdn: 'samedomain.com', ttl: 3600, cname: 'samedomain.com').valid?
  end

  def test_validates_alias
    assert Record::ALIAS.new(fqdn: 'example.com', ttl: 3600, alias: 'example2.com').valid?
    refute Record::ALIAS.new(fqdn: 'samedomain.com', ttl: 3600, alias: 'samedomain.com').valid?
  end

  def test_to_hash
    record = Record::NS.new(fqdn: 'example.com', ttl: 600, nsdname: 'blah.example.com')
    hash = record.to_hash

    assert_equal 'NS', hash[:type]
    assert_equal 'example.com.', hash[:fqdn]
    assert_equal 'blah.example.com.', hash[:nsdname]
    assert_equal 600, hash[:ttl]
  end

  def test_to_json
    record = Record::TXT.new(fqdn: 'example.com.', ttl: 600, txtdata: 'foo')
    hash = record.to_json

    assert_equal 'foo', hash[:rdata][:txtdata]
    assert_equal 600, hash[:ttl]
  end

  def test_record_type
    assert_equal 'TXT', Record::TXT.new(fqdn: 'example.com.', ttl: 600, txtdata: 'foo').type
    assert_equal 'CNAME', Record::CNAME.new(fqdn: 'example.com.', ttl: 600, cname: 'www.example.com').type
  end
end
