# Record Store

Record Store is a tool to manage DNS through a git-based workflow.

## Getting Started

```
record-store apply                     # Applies the DNS changes
record-store assert_empty_diff         # Asserts there is no divergence between DynECT & the zone files
record-store diff                      # Displays the DNS differences between the zone files in this repo and production
record-store download -n, --name=NAME  # Downloads all records from zone and creates YAML zone definition in zones/ e.g. record-store download --name=sho...
record-store freeze                    # Freezes all zones under management to prevent manual edits
record-store help [COMMAND]            # Describe available commands or one specific command
record-store list                      # Lists out records in YAML zonefiles
record-store secrets                   # Decrypts DynECT credentials
record-store sort -n, --name=NAME      # Sorts the zonefile alphabetically e.g. record-store sort --name=shopify.io
record-store thaw                      # Thaws all zones under management to allow manual edits
record-store validate_all_present      # Validates that all the zones that are expected are defined
record-store validate_change_size      # Validates no more then particular limit of DNS records are removed per zone at a time
record-store validate_initial_state    # Validates state hasn't diverged since the last deploy
record-store validate_records          # Validates that all DNS records have valid definitions
```

----

## Architecture

All CLI commands are defined in [`lib/recordstore/cli.rb`](lib/recordstore/cli.rb) with [Thor](https://github.com/erikhuda/thor).

### Zones and Records

The `Zone` and `Record` models are representations of their DNS equivalents. Both have validations to ensure configurations are RFC compliant. These are specified using `ActiveModel::Validations`.

Most CLI interactions are through the `Zone` model.

### Providers

In order to be provider agnostic, Record Store encapsulates all provider interactions in the `Provider` model and its children. A provider is initialized for each `zone`.

Outline of [`Provider`](lib/recordstore/provider.rb):
```ruby
class Provider
  # Creates a new record to the zone. It is expected this call modifies external state.
  #
  # Arguments:
  # record - a kind of `Record`
  def add(record)
  end

  # Deletes an existing record from the zone. It is expected this call modifies external state.
  #
  # Arguments:
  # record - a kind of `Record`
  def remove(record)
  end

  # Updates an existing record in the zone. It is expected this call modifies external state.
  #
  # Arguments:
  # id - provider specific ID of record to update
  # record - a kind of `Record` which the record with `id` should be updated to
  def update(id, record)
  end

  # Downloads all the records from the provider.
  #
  # Returns: an array of `Record` for each record in the provider's zone
  def retrieve_current_records
  end

  # Returns an array of the zones managed by provider as strings
  def zones
  end

  ######## NOTE ########
  # The following methods only need to be implemented if the provider supports the ability to
  # lock/unlock changes to zones.
  ######################

  # Lock the ability to make any changes to the zone without unlocking it first. It is expected
  # this call modifies external state.
  def freeze_zone
  end

  # Unlocks the zone to allow making changes (see `Provider#freeze_zone`).
  def thaw
  end
end
```

#### Adding new Providers

To add a new Provider, create a class inherriting `Provider` in [`lib/recordstore/provider/`](lib/recordstore/provider/). The [DynECT provider](lib/recordstore/provider/dnsimple.rb) is good to use as a reference implementation.

**Note**: _there's no need to wrap `Provider#apply_changeset` unless it's necessary to do something before/after making changes to a zone._

Provider API interactions are tested with [VCR](https://github.com/vcr/vcr). To generate the fixtures, update [`test/dummy/secrets.json`](test/dummy/secrets.json) with valid credentials, run the test suite, and change the values back to stub credentials.

**Important**: _be sure to [filter sensitive data](https://github.com/Shopify/recordstore/blob/1ec0d1410cf8bedf79bc63e8e4cdc7cdb0f1019b/test/test_helper.rb#L23-L56) from the fixtures or you're going to have a bad time._

##### Provider-Specific Records

For provider-specific records (e.g. `ALIAS`), create the record model in `lib/recordstore/record` as any other record. In the provider, extend `self.record_types` and append the custom record types to the `Set` returned by `Provider.record_types` (e.g. [`DNSimple.record_types`](https://github.com/Shopify/recordstore/blob/1ec0d1410cf8bedf79bc63e8e4cdc7cdb0f1019b/lib/recordstore/provider/dnsimple.rb#L5-L7)).

##### Secrets

When adding a new provider, be sure to update the `secrets.json` in [`template/secrets.json`](template/secrets.json) and [`test/dummy/secrets.json`](test/dummy/secrets.json) with the new provider and required fields for the API to work.


### Changeset

Changesets are how Record Store knows what updates to make. A `Changeset` is generated by comparing the current records in a zone with the desired final state. A `Changeset` is composed of one or more `Changeset::Change`. Each `Change` is either an `addition`, `removal`, or `update`. Since the ID of records aren't specified in zone files, FQDNs are used to dedup when records can be updated or when new ones need to be created.

When running `bin/record-store apply`, a `Changeset` is generated by comparing the current records in a zone's YAML file with the records the provider defines. A zone's YAML file is always considered the primary source of truth.

----

## Development

To get started developing on Record Store, run `bin/setup`. This will create a development directory, `dev/`, that mimics what a production directory managing DNS records using Record Store would look like. Use it as a sandbox when developing Record Store.

### Test Changes on Providers

In order to test changes on providers, you're going to need to update `dev/secrets.json` with credentials. **Note**: make sure the credentials are for test zone(s) as the changes specified in the directory **will be applied**.
