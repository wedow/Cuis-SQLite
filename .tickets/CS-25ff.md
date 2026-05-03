---
id: CS-25ff
status: closed
deps: []
links: []
created: 2026-05-03T19:13:52Z
type: feature
priority: 1
assignee: Greg Wedow
tags: [ffi, types]
---
# add sqlite3_bind_int64 and sqlite3_column_int64 FFI bindings

Add 64-bit integer FFI bindings to SqliteLibrary:

- Add apiBindInt64:with:with: calling sqlite3_bind_int64 (takes long long)
- Add apiColumnInt64:with: calling sqlite3_column_int64 (returns long long)
- Update bindArg:at:in: to route large integers through the 64-bit path
- Update execute:args:on:do: caseOf: type 1 to read via apiColumnInt64

Current state: all integers use sqlite3_bind_int (32-bit), causing silent overflow for values > 2147483647. INT64_MAX (9223372036854775807) round-trips as -1.

## Acceptance Criteria

- FFI declarations for sqlite3_bind_int64 and sqlite3_column_int64 exist
- Integers within 32-bit range still round-trip correctly
- Integers up to INT64_MAX round-trip correctly (9223372036854775807)
- Negative large integers round-trip correctly (-9223372036854775808)
- Existing tests pass

