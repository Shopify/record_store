# Record Store

Record Store is a tool to manage DNS through a git-based workflow.


## Development

To get started developing on Record Store, run `bin/setup`. This will create a development directory, `dev/`, that mimics what a production directory managing DNS records using Record Store would look like. Use it as a sandbox when developing Record Store.

### Test Changes on Providers

In order to test changes on providers, you're going to need to update `dev/secrets.json` with credentials. **Note**: make sure the credentials are for test zone(s) as the changes specified in the directory **will be applied**.

----

## Design

Record Store uses [DynECT's DNS API](https://help.dyn.com/rest-resources/) to sync the YAML zone files. DynECT uses an
[update/publish cycle](https://help.dyn.com/understanding-works-api/) in their API which means no changes take place
until POSTing to the publish endpoint. This allows us to handle all failures by discarding the changes we attempted to
create.

The zones managed by Record Store are frozen in DynECT (frozen zones cannot be changed); the deploy process will thaw
them so it can make the necessary changes, and refreeze once the deploy process has completed.


### DynECT permissions

The permissions required are broken into 2 groups:

* READ: `RecordGet`, `ZoneGet`
* WRITE: `RecordAdd`, `RecordDelete`, `ZonePublish`, `ZoneDiscardChangeset`, `ZoneFreeze`, `ZoneThaw`, `ZoneAddNode`,
`ZoneRemoveNode`

All CI validations only require READ permissions; deplyoing requires a user with READ and WRITE permissions.

For a breakdown of what each permssion allows read through [DynECT's permissions guide](https://help.dyn.com/user-and-group-permissions/).
