# CHANGELOG

## 5.4.1
- case-insensitivity for CAA value validation [FEATURE]

## 5.4.0
- add support for CAA records [FEATURE]

## 5.3.0
- case insensitivity for fqns (force to lowercsase) [FEATURE]

## 5.2.2
- support regex based ignore patterns [FEATURE]

## 5.2.1
- remove alias at domain root validation

## 5.2.0
- limit request rate for DynECT API to avoid 429 errors [FEATURE]

## 5.1.1
- allow underscore in CNAME as per RFC [BUGFIX]

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
