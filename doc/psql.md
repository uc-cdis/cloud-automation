# TL;DR

Connect to the `gen3` postgres databases associated with the local environment.

## Example

* `gen3 psql fence`
* `gen3 psql indexd`
* `gen3 psql peregrine`
* `gen3 psql sheepdog`
* extra arguments pass through to `psql`:
```
echo "SELECT 'uid:'||id,email FROM \"User\" WHERE email IS NOT NULL;" | gen3 psql fence --no-align --tuples-only --pset=fieldsep=,
```
