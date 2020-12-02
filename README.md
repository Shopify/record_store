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
record-store validate_change_size      # Validates no more then particular limit of DNS records are removed per zone at a time
record-store validate_initial_state    # Validates state hasn't diverged since the last deploy
record-store validate_records          # Validates that all DNS records have valid definitions
```

## Providers

Below is the list of DNS providers supported by Record Store. PRs [adding more](#adding-new-providers) are welcome.

### DNSimple

Record Store uses DNSimple's [v2 API](https://developer.dnsimple.com/v2/). To use DNSimple, you'll need to add the primary user's `account_id` and `api_token` to `secrets.json`.

### DynECT

In order to use DynECT, you'll need to create a user that has the [correct read and write permissions](#dynect-permissions). Add the user's `username` & `password` (i.e. API password) as well as your DynECT `customer` name to `secrets.json`.

#### Design

The DynECT provider uses [DynECT's DNS API](https://help.dyn.com/rest-resources/) to sync the YAML zone files. DynECT uses an [update/publish cycle](https://help.dyn.com/understanding-works-api/) in their API which means no changes take place until POSTing to the publish endpoint. This allows us to handle all failures by discarding the changes we attempted to create.

The DynECT zones managed by Record Store are frozen in DynECT (frozen zones cannot be changed); the deploy process will thaw them so it can make the necessary changes, and refreeze once the deploy process has completed.


#### DynECT permissions

The permissions required are broken into 2 groups:

* READ: `RecordGet`, `ZoneGet`
* WRITE: `RecordAdd`, `RecordDelete`, `ZonePublish`, `ZoneDiscardChangeset`, `ZoneFreeze`, `ZoneThaw`, `ZoneAddNode`,
`ZoneRemoveNode`

All CI validations only require READ permissions; deploying requires a user with READ and WRITE permissions.

In addition, the `AliasService` permission is required to be able to read or write ALIAS records on DynECT.

For a breakdown of what each permission allows read through [DynECT's permissions guide](https://help.dyn.com/user-and-group-permissions/).

### Google Cloud DNS

In order to use Google Cloud DNS, you'll need to add the `Service Account Credentials` to `secrets.json`. The `Service Account Credentials` is a JSON format file that you need to generate on Google Cloud Platform. You can find more details about the authentication from [here](https://googleapis.dev/ruby/google-cloud-dns/latest/file.AUTHENTICATION.html).

Here's an example of the JSON format file. You can simply copy all information and paste to `secrets.json` under the key, `google_cloud_dns`.
```json
{
"type": "service_account",
"project_id": "[PROJECT-ID]",
"private_key_id": "[KEY-ID]",
"private_key": "-----BEGIN PRIVATE KEY-----\n[PRIVATE-KEY]\n-----END PRIVATE KEY-----\n",
"client_email": "[SERVICE-ACCOUNT-EMAIL]",
"client_id": "[CLIENT-ID]",
"auth_uri": "https://accounts.google.com/o/oauth2/auth",
"token_uri": "https://accounts.google.com/o/oauth2/token",
"auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
"client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/[SERVICE-ACCOUNT-EMAIL]"
}
```

### NS1

To use NS1, you'll need the API key generated from `Account Settings` on NS1 website. Add the generated API to the value of the `api_key` key of the `ns1` object in `secrets.json`.

### Oracle Cloud Infrastructure

In order to use OCI, you'll need to add the `compartment_id`, `user`, `fingerprint`, `key_content`, `tenancy`, and `region` keys to `secrets.json`.

To find the `compartment_id`, the value you need is available in the `Compartment Details`, that you can find by following the `Identity` menu on the website, and selecting the `Compartments` menu. The value you want starts with `ocid1.compartment.oci..` or `ocid1.tenancy.oci..`.

The `user` will be found in the `User Details`, that you can find by following the `Users` on the website, and selecting the `Identity` menu on the website, and the value starts with `ocid1.user.oc1..`.

Regarding the `fingerprint` and `key_content`, you'll need to generate an API Signing Key (key pair) by following [these steps](https://docs.cloud.oracle.com/iaas/Content/API/Concepts/apisigningkey.htm).

The `tenancy` and `region` are in the `Profile` menu. The `tenancy` starts with `ocid1.tenancy.oc1..`.

----

# Architecture

All CLI commands are defined in [`lib/record_store/cli.rb`](lib/record_store/cli.rb) with [Thor](https://github.com/erikhuda/thor).

### Zones and Records

The `Zone` and `Record` models are representations of their DNS equivalents. Both have validations to ensure configurations are RFC compliant. These are specified using `ActiveModel::Validations`.

Most CLI interactions are through the `Zone` model.

### Providers

In order to be provider agnostic, Record Store encapsulates all provider interactions in the `Provider` model and its children. A provider is initialized for each `zone`.


### Changeset

Changesets are how Record Store knows what updates to make. A `Changeset` is generated by comparing the current records in a zone with the desired final state. A `Changeset` is composed of one or more `Changeset::Change`. Each `Change` is either an `addition`, `removal`, or `update`. Since the ID of records aren't specified in zone files, FQDNs are used to dedup when records can be updated or when new ones need to be created.

When running `bin/record-store apply`, a `Changeset` is generated by comparing the current records in a zone's YAML file with the records the provider defines. A zone's YAML file is always considered the primary source of truth.

### Parallelism

Record store attempts to parallelize some of the bulk zone fetching operations. It does so by spawning multiple threads (default: 10). This value can be configured by setting the RECORD_STORE_MAX_THREADS environment variable to a positive integer value.


### Templates

Record Store supports injecting implicit records into a zone based on templates. Each `Zone` can have a list of `Zone::Config::ImplicitRecordTemplate` in its `Zone::Config` that can define their own criteria for which records they use for generating implicit template records, which records conflict with the template-generated records, and what the template-generated records look like. These records are injected at the time of `Zone` initialization within `Zone#build_records`.

Templates can help reduce zone file bloat where instead of defining many generic literals within the zone file for a given criteria zone record, these generic records can be implicitly injected into the `Zone` at the time of initialization based on information provided within the template.

----

# Development

To get started developing on Record Store, run `bin/setup`. This will create a development directory, `dev/`, that mimics what a production directory managing DNS records using Record Store would look like. Use it as a sandbox when developing Record Store.
You can use `bin/console` to get play with the dev data, or you can `cd` into `dev/` and use `bin/record-store` to test out the CLI.

### Adding new Providers

To add a new Provider, create a class inheriting `Provider` in [`lib/record_store/provider/`](lib/record_store/provider/). The [DynECT provider](lib/record_store/provider/dynect.rb) is good to use as a reference implementation.

**Note**: _there's no need to wrap `Provider#apply_changeset` unless it's necessary to do something before/after making changes to a zone._

Provider API interactions are tested with [VCR](https://github.com/vcr/vcr). To generate the fixtures, update [`test/fixtures/config/dummy/secrets.json`](test/fixtures/config/dummy/secrets.json) with valid credentials, run the test suite, and change the values back to stub credentials.

**Important**: _be sure to [filter sensitive data](https://github.com/Shopify/record_store/blob/1ec0d1410cf8bedf79bc63e8e4cdc7cdb0f1019b/test/test_helper.rb#L23-L56) from the fixtures or you're going to have a bad time._

Outline of [`Provider`](lib/record_store/provider.rb):
```ruby
class Provider
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

  private

  ######## NOTE ########
  # The following methods only need to be implemented if you are using the base provider's
  # implementation of apply_changeset to manage the contents of the changeset (or transaction).
  ######################

  # Creates a new record to the zone. It is expected this call modifies external state.
  #
  # Arguments:
  # record - a kind of `Record`
  def add(zone, record)
  end

  # Deletes an existing record from the zone. It is expected this call modifies external state.
  #
  # Arguments:
  # record - a kind of `Record`
  def remove(zone, record)
  end

  # Updates an existing record in the zone. It is expected this call modifies external state.
  #
  # Arguments:
  # id - provider specific ID of record to update
  # record - a kind of `Record` which the record with `id` should be updated to
  def update(zone, id, record)
  end
end
```

#### Provider-Specific Records

For provider-specific records (e.g. `ALIAS`), create the record model in `lib/record_store/record` as any other record. In the provider, extend `self.record_types` and append the custom record types to the `Set` returned by `Provider.record_types` (e.g. [`DNSimple.record_types`](https://github.com/Shopify/record_store/blob/368153106068800325b4e579483faa427afe7add/lib/record_store/provider/dnsimple.rb#L6)).

#### Secrets

When adding a new provider, be sure to update the `secrets.json` in [`template/secrets.json`](template/secrets.json) and [`test/fixtures/config/dummy/secrets.json`](test/fixtures/config/dummy/secrets.json) with the new provider and required fields for the API to work.


### Test Changes on Providers

In order to test changes on providers, you're going to need to update `dev/secrets.json` with credentials. **Note**: make sure the credentials are for test zone(s) as the changes specified in the directory **will be applied**.

# Acknowledgements

Big thanks to [@pjb3](https://github.com/pjb3) for graciously letting us use the `record_store` gem namespace.
