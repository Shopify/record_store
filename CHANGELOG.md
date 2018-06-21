# CHANGELOG

## 5.1.0
- use concurrent sessions when multi-threaded to avoid "This session already has a job running" errors. [BUGFIX]

## 5.0.5
- Output progress messages for GoogleCloudDNS provider too. [BUGFIX]
- Fix quoting/escaping for TXT records. [BUGFIX]
- Make implementation-specific methods of Provider private. [REFACTOR]
- DRY up SPF support to use TXT superclass implementation. [REFACTOR]

## 5.0.4
- Replaces fog-dnsimple with dnsimple-ruby gem. [REFACTOR]

## 5.0.0
- Use DNSimple API v2 (via fog-dnsimple gem update).

## 4.0.7
- Fix issue updating records with same FQDN. [BUGFIX]
