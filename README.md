SQLite3 for Cuis Smalltalk
-----------------

Status: Working in Cuis 7.7


"SQLite is a software library that implements a self-contained, serverless, zero-configuration,
transactional SQL database engine. SQLite is the most widely deployed SQL database engine in the world.
The source code for SQLite
is in the public domain."
https://sqlite.org/

This repository contains the access code to the library for Cuis Smalltalk https://github.com/jvuletich/Cuis.
The code is nearly the same as the original for Squeak Smalltalk.


### Prerequisites

* Cuis 7.7 (or later)
* FFI package (bundled with Cuis, in `Packages/System/FFI.pck.st`)
* SQLite3 shared library installed on your system (`libsqlite3.so` on Linux, `libsqlite3.dylib` on macOS, `sqlite3.dll` on Windows)


### Installation

Using the `cuis` CLI:

```sh
cuis init MyProject
cd MyProject
# Copy SQLite3-Core.pck.st and SQLite3-Tests.pck.st into your project
cuis up dev
cuis pkg load --in dev packages/FFI.pck.st
cuis pkg load --in dev SQLite3-Core.pck.st
```

Or in a running Cuis image:

```smalltalk
Feature require: 'FFI'.
CodePackageFile installPackage: 'SQLite3-Core.pck.st' asFileEntry.
```

### Usage

```smalltalk
| db results |
db := SQLiteConnection fileNamed: '/path/to/database.db'.
"Or in-memory: db := SQLiteConnection fileNamed: ':memory:'."

"Create and populate"
db execute: 'create table employee (id INTEGER PRIMARY KEY, name TEXT)' args: #().
db execute: 'insert into employee values (?, ?)' args: {1. 'Alice'}.
db execute: 'insert into employee values (?, ?)' args: {2. 'Bob'}.

"Query"
results := db executeQuery: 'SELECT * FROM employee'.
results do: [:row | Transcript show: (row at: 'name'); newLine].

"Prepared statements with block"
db execute: 'SELECT name FROM employee WHERE id = ?' args: {1} do: [:name |
    Transcript show: name; newLine].

db close.
```


### Original Squeak files used for the port

* SQLite3-Core-ar.8.mcz
* SQLite3-Tests-ar.4.mcz

from www.squeaksource.com

Author: Andreas Raab

Licence: MIT


### Porting history

1. Original Squeak packages filed into Cuis.
2. Fix in `SqliteResult>>readStringAtAddress:` — removed `basicSqueakToIso` call.
3. All 5 tests passing.
4. Packages saved as `*.pck.st`.
5. Updated for Cuis 7.7: FFI dependency, 64-bit pointer handling, `FinalizationRegistry`, deprecated API replacements.
