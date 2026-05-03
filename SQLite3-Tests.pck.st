'From Cuis7.7 [latest update: #7779] on 3 May 2026 at 12:00:00 pm'!
'Description '!
!provides: 'SQLite3-Tests' 1 1!
!requires: 'SQLite3-Core' 1 1 nil!
!classDefinition: #SQLiteConnectionTest category: #'SQLite3-Tests'!
TestCase subclass: #SQLiteConnectionTest
	instanceVariableNames: 'db'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'SQLite3-Tests'!
!classDefinition: 'SQLiteConnectionTest class' category: #'SQLite3-Tests'!
SQLiteConnectionTest class
	instanceVariableNames: ''!


!SQLiteConnectionTest methodsFor: 'running' stamp: 'pb 1/10/2016 16:28'!
databaseFileName
	"Macs (tested OS X 6.2) require absolute file paths to the database, Windows and Ubuntu do not"
	"
	^ FileDirectory default fullNameFor: self databaseName.
	"
	^ self databaseName asFileEntry asString! !

!SQLiteConnectionTest methodsFor: 'accessing' stamp: 'spd 5/19/2010 14:32'!
databaseName
	^'sqlite_test_database.db'
	
! !

!SQLiteConnectionTest methodsFor: 'accessing' stamp: 'tbn 1/25/2010 20:06'!
defaultTestClass
	^SQLiteConnection ! !

!SQLiteConnectionTest methodsFor: 'running' stamp: 'spd 5/19/2010 14:36'!
setUp
	super setUp.
	
	db := self defaultTestClass fileNamed: self databaseFileName.! !

!SQLiteConnectionTest methodsFor: 'running' stamp: 'pb 1/10/2016 16:26'!
tearDown
	db close.
	"
	FileDirectory default deleteFileNamed: self databaseName.
	"
	self databaseName asFileEntry delete.
	super tearDown! !

!SQLiteConnectionTest methodsFor: 'testing' stamp: 'gw 5/3/2026 12:00'!
testLargeIntegerRoundTrip
	"Large integers (> 32-bit) should survive a round-trip through SQLite"
	| largeInt result |
	largeInt := 2 raisedToInteger: 53. "9007199254740992 - safe 64-bit integer"
	db execute: 'CREATE TABLE bigints (id INTEGER PRIMARY KEY, val INTEGER)' args: {}.
	db execute: 'INSERT INTO bigints (val) VALUES (?)' args: {largeInt}.
	result := nil.
	db execute: 'SELECT val FROM bigints' args: {} do: [:val |
		result := val.
	].
	self assert: result = largeInt! !

!SQLiteConnectionTest methodsFor: 'testing' stamp: 'gw 5/3/2026 12:00'!
testUnicodeStringRoundTrip
	"UnicodeString with multi-byte UTF-8 characters should survive a round-trip through SQLite"
	| u result |
	u := UnicodeString fromUtf8Bytes: (ByteArray with: 99 with: 97 with: 102 with: 195 with: 169). "café"
	db execute: 'CREATE TABLE unicode_test (id INTEGER PRIMARY KEY, name TEXT)' args: {}.
	db execute: 'INSERT INTO unicode_test (name) VALUES (?)' args: {u}.
	result := nil.
	db execute: 'SELECT name FROM unicode_test' args: {} do: [:name |
		result := name.
	].
	self assert: result = u! !

!SQLiteConnectionTest methodsFor: 'testing' stamp: 'tbn 1/25/2010 20:28'!
testInstanceCreation
 
	self 
		assert: db notNil;
		assert: db class = self defaultTestClass;
		deny: (self defaultTestClass registry keys includes: db).
	
! !

!SQLiteConnectionTest methodsFor: 'testing' stamp: 'ar 1/4/2012 10:50'!
testPreparedStatements

	(db execute: 'select * from sqlite_master' args: {}) ifEmpty:[
		db execute: 'create table employee (id INTEGER PRIMARY KEY, name TEXT, created DATE)'
			args: {}.
	].
	db execute: 'insert into employee values (?, ?, ?)' 
		args: {1. 'Adam'. DateAndTime now}.
	db execute: 'insert into employee values (?, ?, ?)' 
		args: {2. 'Eve'. nil}.
	db execute: 'select id, name from employee where name = ?' args: {'Adam'} do:[:id :name|
		self assert: id = 1.
		self assert: name = 'Adam'.
	].

	db execute: 'select * from employee where name = ?' args: {'Eve'} do:[:id :name :created|
		self assert: id = 2.
		self assert: name = 'Eve'.
		self assert: created = nil.
	].
! !

!SQLiteConnectionTest methodsFor: 'testing' stamp: 'tbn 1/25/2010 20:28'!
testRegistration

	db open.
	
	self assert: (self defaultTestClass registry keys includes: db).	
	
	db close.
	
	self deny: (self defaultTestClass registry keys includes: db).	! !

!SQLiteConnectionTest methodsFor: 'testing' stamp: 'tbn 1/25/2010 20:54'!
testTableCreation
	|sql|
	db open.	
	sql := 'CREATE TABLE ABC (ID INTEGER PRIMARY KEY, Name TEXT)'.
	db executeQuery: sql.
	db withResultForQuery: 'select * from sqlite_master;' do: [:each | 
		self assert: sql = (each nextRow at: 'sql')] 
	 ! !

!SQLiteConnectionTest methodsFor: 'testing' stamp: 'tbn 1/25/2010 21:03'!
testUseDatabase
	|s1 s2 s3 arrayOfDicts|
	s1 := 'create table employee (id, name)'.
	s2 := 'insert into employee values (1, ''Adam'')'.
	s3 := 'insert into employee values (2, ''Eve'')'.
	(Array with: s1 with: s2 with: s3)
		do: [:sql | db  executeQuery: sql].
	
	arrayOfDicts := db executeQuery: 'SELECT * FROM employee'.
	self assert: arrayOfDicts size = 2.
	self assert: (arrayOfDicts first at: 'name') = 'Adam'
	! !

!SQLiteConnectionTest methodsFor: 'testing' stamp: 'gw 5/3/2026 12:00'!
testBlobRoundTrip
	"ByteArray should survive a round-trip through a BLOB column"
	| blob result |
	blob := #[1 2 3 4 5].
	db execute: 'CREATE TABLE blob_test (id INTEGER PRIMARY KEY, data BLOB)' args: {}.
	db execute: 'INSERT INTO blob_test (data) VALUES (?)' args: {blob}.
	result := nil.
	db execute: 'SELECT data FROM blob_test' args: {} do: [:data |
		result := data.
	].
	self assert: (result isKindOf: ByteArray).
	self assert: result = blob! !

!SQLiteConnectionTest methodsFor: 'testing' stamp: 'gw 5/3/2026 12:00'!
testEmptyBlobRoundTrip
	"Empty ByteArray should round-trip through a BLOB column"
	| blob result |
	blob := ByteArray new: 0.
	db execute: 'CREATE TABLE empty_blob_test (id INTEGER PRIMARY KEY, data BLOB)' args: {}.
	db execute: 'INSERT INTO empty_blob_test (data) VALUES (?)' args: {blob}.
	result := nil.
	db execute: 'SELECT data FROM empty_blob_test' args: {} do: [:data |
		result := data.
	].
	self assert: (result isKindOf: ByteArray).
	self assert: result size = 0! !

!SQLiteConnectionTest methodsFor: 'testing' stamp: 'gw 5/3/2026 12:00'!
testNullBlobReadsAsNil
	"NULL in a BLOB column should read back as nil"
	| result |
	db execute: 'CREATE TABLE null_blob_test (id INTEGER PRIMARY KEY, data BLOB)' args: {}.
	db execute: 'INSERT INTO null_blob_test (data) VALUES (?)' args: {nil}.
	result := 'notNil'.
	db execute: 'SELECT data FROM null_blob_test' args: {} do: [:data |
		result := data.
	].
	self assert: result isNil! !
