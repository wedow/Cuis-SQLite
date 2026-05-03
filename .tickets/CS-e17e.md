---
id: CS-e17e
status: closed
deps: []
links: []
created: 2026-05-03T19:13:52Z
type: feature
priority: 1
assignee: Greg Wedow
tags: [ffi, types]
---
# add BLOB support (sqlite3_bind_blob, sqlite3_column_blob, sqlite3_column_bytes)

Add BLOB FFI bindings to SqliteLibrary:

- Add apiBindBlob:with:with:with:with: calling sqlite3_bind_blob
- Add apiColumnBlob:with: calling sqlite3_column_blob (returns void*)
- Add apiColumnBytes:with: calling sqlite3_column_bytes (returns int)
- Add ByteArray branch to bindArg:at:in:
- Update execute:args:on:do: caseOf: type 4 to read blob bytes into ByteArray

Current state: type 4 (SQLITE_BLOB) explicitly raises 'Blobs are not supported'. ByteArray args raise 'Cannot bind argument'. No FFI declarations exist for blob functions.

## Acceptance Criteria

- FFI declarations for sqlite3_bind_blob, sqlite3_column_blob, sqlite3_column_bytes exist
- ByteArray values can be bound as BLOB parameters
- BLOB columns read back as ByteArray
- Empty ByteArray round-trips correctly
- NULL BLOB column reads back as nil
- Existing tests pass

