'From Cuis 7.7 [latest update: #0] on 24 April 2026 at 12:00:00 pm'!
'Description CuisAgentBridge exposes a local JSON RPC bridge for agent driven live image development. It is intended to be loaded by the cuis Bash CLI. The bridge supports eval, browse, compile, package, test, object inspection, and debugger reference operations.'!
!provides: 'CuisAgentBridge' 1 0!
!requires: 'JSON' nil nil nil!
!requires: 'WebClient' nil nil nil!
SystemOrganization addCategory: #'CuisAgentBridge'!

!classDefinition: #CuisAgentBridge category: #'CuisAgentBridge'!
Object subclass: #CuisAgentBridge
	instanceVariableNames: 'server port token sessionName stateFilePath objects debuggers nextObjectId nextDebuggerId'
	classVariableNames: 'Current'
	poolDictionaries: ''
	category: 'CuisAgentBridge'!
!classDefinition: 'CuisAgentBridge class' category: #'CuisAgentBridge'!
CuisAgentBridge class
	instanceVariableNames: ''!

!classDefinition: #CuisAgentDebugSession category: #'CuisAgentBridge'!
Object subclass: #CuisAgentDebugSession
	instanceVariableNames: 'id exception context process createdAt state'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'CuisAgentBridge'!
!classDefinition: 'CuisAgentDebugSession class' category: #'CuisAgentBridge'!
CuisAgentDebugSession class
	instanceVariableNames: ''!

!CuisAgentBridge class methodsFor: 'instance creation' stamp: 'ai 4/24/2026 12:00'!
current
	^Current! !

!CuisAgentBridge class methodsFor: 'instance creation' stamp: 'ai 4/24/2026 12:00'!
startOn: anInteger token: aString session: sessionString stateFile: pathString
	Current ifNotNil: [ Current stop ].
	Current := self new.
	Current startOn: anInteger token: aString session: sessionString stateFile: pathString.
	^Current! !

!CuisAgentBridge class methodsFor: 'instance creation' stamp: 'ai 4/24/2026 12:00'!
stopCurrent
	Current ifNotNil: [ Current stop ].
	Current := nil! !

!CuisAgentBridge class methodsFor: 'instance creation' stamp: 'ai 4/24/2026 12:00'!
version
	^'1.0.0'! !

!CuisAgentBridge methodsFor: 'initialization' stamp: 'ai 4/24/2026 12:00'!
initialize
	super initialize.
	objects := Dictionary new.
	debuggers := Dictionary new.
	nextObjectId := 0.
	nextDebuggerId := 0! !

!CuisAgentBridge methodsFor: 'initialization' stamp: 'ai 4/24/2026 12:00'!
startOn: anInteger token: aString session: sessionString stateFile: pathString
	self initialize.
	port := anInteger.
	token := aString.
	sessionName := sessionString.
	stateFilePath := pathString.
	server := WebServer new listenOn: port.
	server addService: '/health' action: [ :request | self handleHealth: request ].
	server addService: '/rpc' action: [ :request | self handleRpc: request ].
	self writeStateFile.
	^self! !

!CuisAgentBridge methodsFor: 'initialization' stamp: 'ai 4/24/2026 12:00'!
stop
	server ifNotNil: [
		(server respondsTo: #stop) ifTrue: [ [ server stop ] on: Error do: [ :ex | ex return ] ].
		(server respondsTo: #destroy) ifTrue: [ [ server destroy ] on: Error do: [ :ex | ex return ] ].
		(server respondsTo: #close) ifTrue: [ [ server close ] on: Error do: [ :ex | ex return ] ] ].
	server := nil! !

!CuisAgentBridge methodsFor: 'http' stamp: 'ai 4/24/2026 12:00'!
handleHealth: aRequest
	| response |
	response := Dictionary new.
	response at: 'status' put: 'ok'.
	response at: 'session' put: sessionName.
	response at: 'version' put: self class version.
	self sendJson: response to: aRequest! !

!CuisAgentBridge methodsFor: 'http' stamp: 'ai 4/24/2026 12:00'!
handleRpc: aRequest
	| payload response op args |
	[
		payload := self requestPayloadFrom: aRequest.
		(self tokenMatchesPayload: payload) ifFalse: [
			response := self errorResponse: 'unauthorized'.
			^self sendJson: response to: aRequest ].
		op := payload at: 'op' ifAbsent: [ '' ].
		args := payload at: 'args' ifAbsent: [ Dictionary new ].
		response := self dispatch: op args: args.
		self sendJson: response to: aRequest ]
		on: Exception
		do: [ :ex |
			[ self sendJson: (self errorResponse: (self safePrint: ex)) to: aRequest ]
				on: Error do: [ :err | ] ]! !

!CuisAgentBridge methodsFor: 'http' stamp: 'ai 4/24/2026 12:00'!
requestPayloadFrom: aRequest
	| body |
	body := (aRequest respondsTo: #content)
		ifTrue: [ aRequest content ]
		ifFalse: [ '{}' ].
	body ifNil: [ body := '{}' ].
	body := body asString.
	body isEmpty ifTrue: [ body := '{}' ].
	^Json readFrom: body readStream! !

!CuisAgentBridge methodsFor: 'http' stamp: 'ai 4/24/2026 12:00'!
sendJson: aDictionary to: aRequest
	| text |
	text := Json render: aDictionary.
	(aRequest respondsTo: #send200Response:contentType:)
		ifTrue: [ ^aRequest send200Response: text contentType: 'application/json; charset=utf-8' ].
	^aRequest send200Response: text! !

!CuisAgentBridge methodsFor: 'http' stamp: 'ai 4/24/2026 12:00'!
tokenMatchesPayload: aDictionary
	^(aDictionary at: 'token' ifAbsent: [ '' ]) = token! !

!CuisAgentBridge methodsFor: 'http' stamp: 'ai 4/24/2026 12:00'!
writeStateFile
	| state |
	stateFilePath ifNil: [ ^self ].
	state := Dictionary new.
	state at: 'status' put: 'ok'.
	state at: 'session' put: sessionName.
	state at: 'port' put: port.
	state at: 'endpoint' put: ('http://127.0.0.1:', port printString).
	[ stateFilePath asFileEntry forceWriteStreamDo: [ :stream | stream nextPutAll: (Json render: state) ] ]
		on: Error
		do: [ :ex | ex return ]! !

!CuisAgentBridge methodsFor: 'responses' stamp: 'ai 4/24/2026 12:00'!
okResponse
	| d |
	d := Dictionary new.
	d at: 'status' put: 'ok'.
	^d! !

!CuisAgentBridge methodsFor: 'responses' stamp: 'ai 4/24/2026 12:00'!
errorResponse: aString
	| d |
	d := Dictionary new.
	d at: 'status' put: 'error'.
	d at: 'message' put: aString asString.
	^d! !

!CuisAgentBridge methodsFor: 'responses' stamp: 'ai 4/24/2026 12:00'!
unsupportedResponse: aString
	| d |
	d := Dictionary new.
	d at: 'status' put: 'unsupported'.
	d at: 'message' put: aString asString.
	^d! !

!CuisAgentBridge methodsFor: 'responses' stamp: 'ai 4/24/2026 12:00'!
responseForResult: anObject retain: retainBoolean
	| d |
	d := Dictionary new.
	d at: 'status' put: 'ok'.
	d at: 'result' put: (self safePrint: anObject).
	d at: 'class' put: ([ anObject class name asString ] on: Error do: [ :ex | 'unknown' ]).
	retainBoolean ifTrue: [ d at: 'object' put: (self retainObject: anObject) ].
	^d! !

!CuisAgentBridge methodsFor: 'dispatch' stamp: 'ai 4/24/2026 12:00'!
dispatch: op args: args
	op = 'health' ifTrue: [ ^self okResponse ].
	op = 'lifecycle.stop' ifTrue: [ ^self lifecycleStop ].
	op = 'eval' ifTrue: [ ^self evaluateArgs: args ].
	op = 'run' ifTrue: [ ^self runArgs: args ].
	op = 'browse.class' ifTrue: [ ^self browseClassArgs: args ].
	op = 'browse.method' ifTrue: [ ^self browseMethodArgs: args ].
	op = 'browse.senders' ifTrue: [ ^self browseSendersArgs: args ].
	op = 'browse.implementors' ifTrue: [ ^self browseImplementorsArgs: args ].
	op = 'browse.package' ifTrue: [ ^self browsePackageArgs: args ].
	op = 'browse.categories' ifTrue: [ ^self browseCategoriesArgs: args ].
	op = 'browse.classes' ifTrue: [ ^self browseClassesArgs: args ].
	op = 'browse.hierarchy' ifTrue: [ ^self browseHierarchyArgs: args ].
	op = 'compile.method' ifTrue: [ ^self compileMethodArgs: args ].
	op = 'compile.class' ifTrue: [ ^self compileClassArgs: args ].
	op = 'compile.doit' ifTrue: [ ^self compileDoitArgs: args ].
	op = 'remove.method' ifTrue: [ ^self removeMethodArgs: args ].
	op = 'remove.class' ifTrue: [ ^self removeClassArgs: args ].
	op = 'dbg.list' ifTrue: [ ^self debugList ].
	op = 'dbg.stack' ifTrue: [ ^self debugStackArgs: args ].
	op = 'dbg.frame' ifTrue: [ ^self debugFrameArgs: args ].
	op = 'dbg.vars' ifTrue: [ ^self debugVarsArgs: args ].
	op = 'dbg.source' ifTrue: [ ^self debugSourceArgs: args ].
	op = 'dbg.eval' ifTrue: [ ^self debugEvalArgs: args ].
	op = 'dbg.into' ifTrue: [ ^self debugStepArgs: args kind: 'into' ].
	op = 'dbg.over' ifTrue: [ ^self debugStepArgs: args kind: 'over' ].
	op = 'dbg.through' ifTrue: [ ^self debugStepArgs: args kind: 'through' ].
	op = 'dbg.restart' ifTrue: [ ^self debugRestartArgs: args ].
	op = 'dbg.proceed' ifTrue: [ ^self debugProceedArgs: args ].
	op = 'dbg.abort' ifTrue: [ ^self debugAbortArgs: args ].
	op = 'dbg.release' ifTrue: [ ^self debugReleaseArgs: args ].
	op = 'inspect' ifTrue: [ ^self inspectArgs: args ].
	op = 'send' ifTrue: [ ^self sendArgs: args ].
	op = 'pkg.list' ifTrue: [ ^self pkgListArgs: args ].
	op = 'pkg.dirty' ifTrue: [ ^self pkgDirtyArgs: args ].
	op = 'pkg.load' ifTrue: [ ^self pkgLoadArgs: args ].
	op = 'pkg.save' ifTrue: [ ^self pkgSaveArgs: args ].
	op = 'pkg.path' ifTrue: [ ^self pkgPathArgs: args ].
	op = 'pkg.deps' ifTrue: [ ^self pkgDepsArgs: args ].
	op = 'test.run' ifTrue: [ ^self testRunArgs: args ].
	^self errorResponse: ('unknown op: ', op asString)! !

!CuisAgentBridge methodsFor: 'lifecycle' stamp: 'ai 4/24/2026 12:00'!
lifecycleStop
	| d |
	d := self okResponse.
	d at: 'message' put: 'stopping'.
	[ [ self stop ] fork ] on: Error do: [ :ex | ex return ].
	^d! !

!CuisAgentBridge methodsFor: 'utilities' stamp: 'ai 4/24/2026 12:00'!
safePrint: anObject
	^[ anObject printString ] on: Error do: [ :ex | '<print failed>' ]! !

!CuisAgentBridge methodsFor: 'utilities' stamp: 'ai 4/24/2026 12:00'!
classNamed: aString
	^Smalltalk at: aString asString asSymbol ifAbsent: [ nil ]! !

!CuisAgentBridge methodsFor: 'utilities' stamp: 'ai 4/24/2026 12:00'!
selectorFrom: aString
	^aString asString asSymbol! !

!CuisAgentBridge methodsFor: 'utilities' stamp: 'ai 4/24/2026 12:00'!
sideForClassNamed: className classSide: classSideBoolean
	| class |
	class := self classNamed: className.
	class ifNil: [ ^nil ].
	classSideBoolean ifTrue: [ ^class class ].
	^class! !

!CuisAgentBridge methodsFor: 'utilities' stamp: 'ai 4/24/2026 12:00'!
stringArrayFrom: aCollection
	| out |
	out := OrderedCollection new.
	aCollection do: [ :each | out add: each asString ].
	^out asArray! !

!CuisAgentBridge methodsFor: 'utilities' stamp: 'ai 4/24/2026 12:00'!
methodSourceFor: aCompiledMethod
	(aCompiledMethod respondsTo: #sourceCode) ifTrue: [ ^aCompiledMethod sourceCode ].
	(aCompiledMethod respondsTo: #getSource) ifTrue: [ ^aCompiledMethod getSource ].
	^self safePrint: aCompiledMethod! !

!CuisAgentBridge methodsFor: 'object registry' stamp: 'ai 4/24/2026 12:00'!
retainObject: anObject
	| key |
	nextObjectId := nextObjectId + 1.
	key := 'obj_', nextObjectId printString.
	objects at: key put: anObject.
	^key! !

!CuisAgentBridge methodsFor: 'object registry' stamp: 'ai 4/24/2026 12:00'!
objectForId: aString
	^objects at: aString ifAbsent: [ nil ]! !

!CuisAgentBridge methodsFor: 'object registry' stamp: 'ai 4/24/2026 12:00'!
inspectArgs: args
	| obj slot d vars names |
	obj := self objectForId: (args at: 'object' ifAbsent: [ '' ]).
	obj ifNil: [ ^self errorResponse: 'unknown object ref' ].
	slot := args at: 'slot' ifAbsent: [ '' ].
	slot isEmpty ifFalse: [
		[(obj instVarNamed: slot) ifNotNil: [ :value | ^self responseForResult: value retain: true ]]
			on: Error
			do: [ :ex | ^self errorResponse: (self safePrint: ex) ] ].
	d := Dictionary new.
	d at: 'status' put: 'ok'.
	d at: 'object' put: (args at: 'object').
	d at: 'class' put: obj class name asString.
	d at: 'printString' put: (self safePrint: obj).
	vars := OrderedCollection new.
	names := obj class allInstVarNames.
	1 to: names size do: [ :index |
		| each |
		each := Dictionary new.
		each at: 'name' put: (names at: index) asString.
		each at: 'value' put: (self safePrint: (obj instVarAt: index)).
		vars add: each ].
	d at: 'instVars' put: vars asArray.
	^d! !

!CuisAgentBridge methodsFor: 'object registry' stamp: 'ai 4/24/2026 12:00'!
sendArgs: args
	| obj selector values result |
	obj := self objectForId: (args at: 'object' ifAbsent: [ '' ]).
	obj ifNil: [ ^self errorResponse: 'unknown object ref' ].
	selector := self selectorFrom: (args at: 'selector' ifAbsent: [ '' ]).
	values := args at: 'args' ifAbsent: [ #() ].
	[ result := obj perform: selector withArguments: values asArray.
	^self responseForResult: result retain: true ]
		on: Exception
		do: [ :ex | ^self captureException: ex ]! !

!CuisAgentBridge methodsFor: 'evaluation' stamp: 'ai 4/25/2026 12:00'!
runHeadless: aBlock
	"Evaluate aBlock suppressing UI-facing side effects: change notifications (which block when headless subscribers try to refresh), answer prompts, and progress bars. Class installation and ChangeSet logging still occur — only observer broadcasts are silenced."
	| provideAnswer |
	provideAnswer := Smalltalk at: #ProvideAnswerNotification ifAbsent: [ nil ].
	^ SystemChangeNotifier uniqueInstance doSilently: [
		[ provideAnswer
			ifNil: [ aBlock value ]
			ifNotNil: [ [ aBlock value ] on: provideAnswer do: [ :n | n resume: true ] ] ]
			on: ProgressInitiationException
			do: [ :ex | ex resume: ((ex instVarNamed: 'workBlock') value: [ :v | ]) ] ]! !

!CuisAgentBridge methodsFor: 'evaluation' stamp: 'ai 4/25/2026 12:00'!
evaluateArgs: args
	| code retain value |
	code := args at: 'code' ifAbsent: [ '' ].
	retain := args at: 'retain' ifAbsent: [ false ].
	[ value := self runHeadless: [
		Compiler new
			evaluate: code
			in: nil
			to: nil
			notifying: nil
			ifFail: [ ^self errorResponse: 'compilation failed' ] ].
	^self responseForResult: value retain: retain ]
		on: UndeclaredVariableReference, UndeclaredVariableWarning
		do: [ :ex | ^self errorResponse: (self safePrint: ex) ];
		on: Exception
		do: [ :ex | ^self captureException: ex ]! !

!CuisAgentBridge methodsFor: 'evaluation' stamp: 'ai 4/25/2026 12:00'!
runArgs: args
	| source path value |
	source := args at: 'source' ifAbsent: [ '' ].
	path := args at: 'path' ifAbsent: [ '' ].
	[ value := self runHeadless: [
		Compiler new
			evaluate: source
			in: nil
			to: nil
			notifying: nil
			ifFail: [ ^self errorResponse: 'compilation failed' ] ].
	^self responseForResult: value retain: false ]
		on: UndeclaredVariableReference, UndeclaredVariableWarning
		do: [ :ex | ^self errorResponse: (self safePrint: ex) ];
		on: Exception
		do: [ :ex | ^self captureException: ex ]! !

!CuisAgentBridge methodsFor: 'debugging' stamp: 'ai 4/24/2026 12:00'!
nextDebuggerIdString
	nextDebuggerId := nextDebuggerId + 1.
	^'dbg_', nextDebuggerId printString! !

!CuisAgentBridge methodsFor: 'debugging' stamp: 'ai 4/24/2026 12:00'!
captureException: anException
	| debug id response |
	id := self nextDebuggerIdString.
	debug := CuisAgentDebugSession id: id exception: anException process: Processor activeProcess.
	debuggers at: id put: debug.
	response := Dictionary new.
	response at: 'status' put: 'debug'.
	response at: 'debugger' put: id.
	response at: 'exception' put: (self safePrint: anException).
	response at: 'topFrame' put: debug topFrameSummary.
	response at: 'stackPreview' put: debug stackPreview.
	^response! !

!CuisAgentBridge methodsFor: 'debugging' stamp: 'ai 4/24/2026 12:00'!
debuggerForId: aString
	^debuggers at: aString ifAbsent: [ nil ]! !

!CuisAgentBridge methodsFor: 'debugging' stamp: 'ai 4/24/2026 12:00'!
debugList
	| d arr |
	d := self okResponse.
	arr := OrderedCollection new.
	debuggers keysAndValuesDo: [ :key :debug |
		| item |
		item := Dictionary new.
		item at: 'debugger' put: key.
		item at: 'exception' put: debug exceptionString.
		item at: 'state' put: debug state asString.
		arr add: item ].
	d at: 'debuggers' put: arr asArray.
	^d! !

!CuisAgentBridge methodsFor: 'debugging' stamp: 'ai 4/24/2026 12:00'!
debugStackArgs: args
	| debug d |
	debug := self debuggerForId: (args at: 'debugger' ifAbsent: [ '' ]).
	debug ifNil: [ ^self errorResponse: 'unknown debugger ref' ].
	d := self okResponse.
	d at: 'debugger' put: debug id.
	d at: 'stack' put: debug stackSummaries.
	^d! !

!CuisAgentBridge methodsFor: 'debugging' stamp: 'ai 4/24/2026 12:00'!
debugFrameArgs: args
	| debug index d |
	debug := self debuggerForId: (args at: 'debugger' ifAbsent: [ '' ]).
	debug ifNil: [ ^self errorResponse: 'unknown debugger ref' ].
	index := (args at: 'index' ifAbsent: [ 0 ]) asNumber.
	d := self okResponse.
	d at: 'frame' put: (debug frameSummaryAt: index).
	^d! !

!CuisAgentBridge methodsFor: 'debugging' stamp: 'ai 4/24/2026 12:00'!
debugVarsArgs: args
	| debug index d |
	debug := self debuggerForId: (args at: 'debugger' ifAbsent: [ '' ]).
	debug ifNil: [ ^self errorResponse: 'unknown debugger ref' ].
	index := (args at: 'index' ifAbsent: [ 0 ]) asNumber.
	d := self okResponse.
	d at: 'vars' put: (debug varsAt: index).
	^d! !

!CuisAgentBridge methodsFor: 'debugging' stamp: 'ai 4/24/2026 12:00'!
debugSourceArgs: args
	| debug index d |
	debug := self debuggerForId: (args at: 'debugger' ifAbsent: [ '' ]).
	debug ifNil: [ ^self errorResponse: 'unknown debugger ref' ].
	index := (args at: 'index' ifAbsent: [ 0 ]) asNumber.
	d := self okResponse.
	d at: 'source' put: (debug sourceAt: index).
	^d! !

!CuisAgentBridge methodsFor: 'debugging' stamp: 'ai 4/24/2026 12:00'!
debugEvalArgs: args
	| debug index code result |
	debug := self debuggerForId: (args at: 'debugger' ifAbsent: [ '' ]).
	debug ifNil: [ ^self errorResponse: 'unknown debugger ref' ].
	index := (args at: 'index' ifAbsent: [ 0 ]) asNumber.
	code := args at: 'code' ifAbsent: [ '' ].
	[ result := debug evaluate: code at: index.
	^self responseForResult: result retain: true ]
		on: Exception
		do: [ :ex | ^self captureException: ex ]! !

!CuisAgentBridge methodsFor: 'debugging' stamp: 'ai 4/24/2026 12:00'!
debugStepArgs: args kind: kindString
	| debug |
	debug := self debuggerForId: (args at: 'debugger' ifAbsent: [ '' ]).
	debug ifNil: [ ^self errorResponse: 'unknown debugger ref' ].
	^debug stepKind: kindString! !

!CuisAgentBridge methodsFor: 'debugging' stamp: 'ai 4/24/2026 12:00'!
debugRestartArgs: args
	| debug index |
	debug := self debuggerForId: (args at: 'debugger' ifAbsent: [ '' ]).
	debug ifNil: [ ^self errorResponse: 'unknown debugger ref' ].
	index := (args at: 'index' ifAbsent: [ 0 ]) asNumber.
	^debug restartAt: index! !

!CuisAgentBridge methodsFor: 'debugging' stamp: 'ai 4/24/2026 12:00'!
debugProceedArgs: args
	| debug |
	debug := self debuggerForId: (args at: 'debugger' ifAbsent: [ '' ]).
	debug ifNil: [ ^self errorResponse: 'unknown debugger ref' ].
	^debug proceed! !

!CuisAgentBridge methodsFor: 'debugging' stamp: 'ai 4/24/2026 12:00'!
debugAbortArgs: args
	| debug |
	debug := self debuggerForId: (args at: 'debugger' ifAbsent: [ '' ]).
	debug ifNil: [ ^self errorResponse: 'unknown debugger ref' ].
	^debug abort! !

!CuisAgentBridge methodsFor: 'debugging' stamp: 'ai 4/24/2026 12:00'!
debugReleaseArgs: args
	| key d |
	key := args at: 'debugger' ifAbsent: [ '' ].
	debuggers removeKey: key ifAbsent: [ ].
	d := self okResponse.
	d at: 'debugger' put: key.
	^d! !

!CuisAgentBridge methodsFor: 'browsing' stamp: 'ai 4/24/2026 12:00'!
browseClassArgs: args
	| class d |
	class := self classNamed: (args at: 'className' ifAbsent: [ '' ]).
	class ifNil: [ ^self errorResponse: 'class not found' ].
	d := self okResponse.
	d at: 'class' put: class name asString.
	d at: 'superclass' put: (class superclass ifNil: [ '' ] ifNotNil: [ class superclass name asString ]).
	d at: 'category' put: class category asString.
	d at: 'instVars' put: (self stringArrayFrom: class instVarNames).
	d at: 'classVars' put: (self stringArrayFrom: class classPool keys).
	d at: 'selectors' put: (self stringArrayFrom: class selectors asArray sort).
	d at: 'classSelectors' put: (self stringArrayFrom: class class selectors asArray sort).
	^d! !

!CuisAgentBridge methodsFor: 'browsing' stamp: 'ai 4/24/2026 12:00'!
browseMethodArgs: args
	| side selector method d |
	side := self sideForClassNamed: (args at: 'className' ifAbsent: [ '' ]) classSide: (args at: 'classSide' ifAbsent: [ false ]).
	side ifNil: [ ^self errorResponse: 'class not found' ].
	selector := self selectorFrom: (args at: 'selector' ifAbsent: [ '' ]).
	method := side compiledMethodAt: selector ifAbsent: [ nil ].
	method ifNil: [ ^self errorResponse: 'method not found' ].
	d := self okResponse.
	d at: 'class' put: side name asString.
	d at: 'selector' put: selector asString.
	d at: 'category' put: (side organization categoryOfElement: selector) asString.
	d at: 'source' put: (self methodSourceFor: method).
	^d! !

!CuisAgentBridge methodsFor: 'browsing' stamp: 'ai 4/24/2026 12:00'!
methodRecordFor: behavior selector: selector includeSource: includeSource
	| d method nonMeta classSide |
	method := behavior compiledMethodAt: selector ifAbsent: [ nil ].
	nonMeta := (behavior respondsTo: #theNonMetaClass)
		ifTrue: [ behavior theNonMetaClass ]
		ifFalse: [ behavior ].
	classSide := (behavior respondsTo: #isMeta)
		ifTrue: [ behavior isMeta ]
		ifFalse: [ false ].
	d := Dictionary new.
	d at: 'class' put: nonMeta name asString.
	d at: 'classSide' put: classSide.
	d at: 'selector' put: selector asString.
	method ifNotNil: [
		d at: 'category' put: (behavior organization categoryOfElement: selector) asString.
		includeSource ifTrue: [ d at: 'source' put: (self methodSourceFor: method) ] ].
	^d! !

!CuisAgentBridge methodsFor: 'browsing' stamp: 'ai 4/24/2026 12:00'!
browseImplementorsArgs: args
	| selector d arr |
	selector := self selectorFrom: (args at: 'selector' ifAbsent: [ '' ]).
	arr := OrderedCollection new.
	Smalltalk allClasses do: [ :class |
		(class includesSelector: selector) ifTrue: [ arr add: (self methodRecordFor: class selector: selector includeSource: false) ].
		(class class includesSelector: selector) ifTrue: [ arr add: (self methodRecordFor: class class selector: selector includeSource: false) ] ].
	d := self okResponse.
	d at: 'selector' put: selector asString.
	d at: 'implementors' put: arr asArray.
	^d! !

!CuisAgentBridge methodsFor: 'browsing' stamp: 'ai 4/24/2026 12:00'!
browseSendersArgs: args
	| selector selectorString d arr |
	selector := self selectorFrom: (args at: 'selector' ifAbsent: [ '' ]).
	selectorString := selector asString.
	arr := OrderedCollection new.
	Smalltalk allClasses do: [ :class |
		class selectors do: [ :sel |
			| source |
			source := self methodSourceFor: (class compiledMethodAt: sel).
			((source findString: selectorString startingAt: 1) > 0) ifTrue: [ arr add: (self methodRecordFor: class selector: sel includeSource: false) ] ].
		class class selectors do: [ :sel |
			| source |
			source := self methodSourceFor: (class class compiledMethodAt: sel).
			((source findString: selectorString startingAt: 1) > 0) ifTrue: [ arr add: (self methodRecordFor: class class selector: sel includeSource: false) ] ] ].
	d := self okResponse.
	d at: 'selector' put: selectorString.
	d at: 'senders' put: arr asArray.
	^d! !

!CuisAgentBridge methodsFor: 'browsing' stamp: 'ai 4/24/2026 12:00'!
browseCategoriesArgs: args
	| d categories |
	categories := (Smalltalk at: #SystemOrganization ifAbsent: [ nil ]) ifNil: [ #() ] ifNotNil: [ SystemOrganization categories ].
	d := self okResponse.
	d at: 'categories' put: (self stringArrayFrom: categories).
	^d! !

!CuisAgentBridge methodsFor: 'browsing' stamp: 'ai 4/24/2026 12:00'!
browseClassesArgs: args
	| pattern d arr |
	pattern := (args at: 'pattern' ifAbsent: [ '' ]) asString.
	arr := OrderedCollection new.
	Smalltalk allClasses do: [ :class |
		(pattern isEmpty or: [ (class name asString findString: pattern startingAt: 1) > 0 ]) ifTrue: [ arr add: class name asString ] ].
	d := self okResponse.
	d at: 'classes' put: arr asArray sort.
	^d! !

!CuisAgentBridge methodsFor: 'browsing' stamp: 'ai 4/24/2026 12:00'!
browseHierarchyArgs: args
	| class d arr current |
	class := self classNamed: (args at: 'className' ifAbsent: [ '' ]).
	class ifNil: [ ^self errorResponse: 'class not found' ].
	arr := OrderedCollection new.
	current := class.
	[current notNil] whileTrue: [ arr addFirst: current name asString. current := current superclass ].
	d := self okResponse.
	d at: 'class' put: class name asString.
	d at: 'hierarchy' put: arr asArray.
	^d! !

!CuisAgentBridge methodsFor: 'browsing' stamp: 'ai 4/24/2026 12:00'!
browsePackageArgs: args
	| packageName package d |
	packageName := args at: 'package' ifAbsent: [ '' ].
	package := self packageNamed: packageName.
	package ifNil: [ ^self errorResponse: 'package not found' ].
	d := self okResponse.
	d at: 'package' put: (self packageNameFor: package).
	d at: 'printString' put: (self safePrint: package).
	(package respondsTo: #classes) ifTrue: [ d at: 'classes' put: (self stringArrayFrom: (package classes collect: [ :each | each name ])) ].
	^d! !

!CuisAgentBridge methodsFor: 'compiling' stamp: 'ai 4/24/2026 12:00'!
compileMethodArgs: args
	| side source category selector d |
	side := self sideForClassNamed: (args at: 'className' ifAbsent: [ '' ]) classSide: (args at: 'classSide' ifAbsent: [ false ]).
	side ifNil: [ ^self errorResponse: 'class not found' ].
	source := args at: 'source' ifAbsent: [ '' ].
	category := args at: 'category' ifAbsent: [ 'agent generated' ].
	[ (side respondsTo: #compileSilently:classified:)
		ifTrue: [ side compileSilently: source classified: category ]
		ifFalse: [ side compile: source classified: category ].
	selector := args at: 'selector' ifAbsent: [ '' ].
	d := self okResponse.
	d at: 'class' put: side name asString.
	d at: 'selector' put: selector asString.
	d at: 'category' put: category.
	^d ]
		on: Exception
		do: [ :ex | ^self captureException: ex ]! !

!CuisAgentBridge methodsFor: 'compiling' stamp: 'ai 4/24/2026 12:00'!
compileClassArgs: args
	| source result |
	source := args at: 'source' ifAbsent: [ '' ].
	[ result := self runHeadless: [
		[ Compiler evaluate: source ]
			on: Warning do: [ :w | w resume ] ].
	^self responseForResult: result retain: false ]
		on: Exception
		do: [ :ex | ^self captureException: ex ]! !

!CuisAgentBridge methodsFor: 'compiling' stamp: 'ai 4/24/2026 12:00'!
compileDoitArgs: args
	| source result |
	source := args at: 'source' ifAbsent: [ '' ].
	[ result := self runHeadless: [ Compiler evaluate: source ].
	^self responseForResult: result retain: false ]
		on: Exception
		do: [ :ex | ^self captureException: ex ]! !

!CuisAgentBridge methodsFor: 'removing' stamp: 'ai 4/24/2026 12:00'!
removeMethodArgs: args
	| side selector d |
	side := self sideForClassNamed: (args at: 'className' ifAbsent: [ '' ]) classSide: (args at: 'classSide' ifAbsent: [ false ]).
	side ifNil: [ ^self errorResponse: 'class not found' ].
	selector := self selectorFrom: (args at: 'selector' ifAbsent: [ '' ]).
	[ (side respondsTo: #removeSelectorSilently:)
		ifTrue: [ side removeSelectorSilently: selector ]
		ifFalse: [ side removeSelector: selector ].
	d := self okResponse.
	d at: 'class' put: side name asString.
	d at: 'selector' put: selector asString.
	^d ]
		on: Exception
		do: [ :ex | ^self captureException: ex ]! !

!CuisAgentBridge methodsFor: 'removing' stamp: 'ai 4/24/2026 12:00'!
removeClassArgs: args
	| class d |
	class := self classNamed: (args at: 'className' ifAbsent: [ '' ]).
	class ifNil: [ ^self errorResponse: 'class not found' ].
	[ (class respondsTo: #removeFromSystemUnlogged)
		ifTrue: [ class removeFromSystemUnlogged ]
		ifFalse: [ class removeFromSystem ].
	d := self okResponse.
	d at: 'class' put: class name asString.
	^d ]
		on: Exception
		do: [ :ex | ^self captureException: ex ]! !

!CuisAgentBridge methodsFor: 'packages' stamp: 'ai 4/24/2026 12:00'!
codePackageClass
	^Smalltalk at: #CodePackage ifAbsent: [ nil ]! !

!CuisAgentBridge methodsFor: 'packages' stamp: 'ai 4/24/2026 12:00'!
packageNameFor: aPackage
	(aPackage respondsTo: #packageName) ifTrue: [ ^aPackage packageName asString ].
	(aPackage respondsTo: #name) ifTrue: [ ^aPackage name asString ].
	^aPackage printString! !

!CuisAgentBridge methodsFor: 'packages' stamp: 'ai 4/24/2026 12:00'!
installedPackages
	| class packages |
	class := self codePackageClass.
	class ifNil: [ ^#() ].
	packages := class installedPackages.
	(packages isKindOf: Dictionary) ifTrue: [ ^packages values ].
	^packages! !

!CuisAgentBridge methodsFor: 'packages' stamp: 'ai 4/24/2026 12:00'!
packageNamed: aString
	self installedPackages do: [ :pkg | (self packageNameFor: pkg) = aString asString ifTrue: [ ^pkg ] ].
	^nil! !

!CuisAgentBridge methodsFor: 'packages' stamp: 'ai 4/24/2026 12:00'!
packageInfoFor: pkg
	| d |
	d := Dictionary new.
	d at: 'name' put: (self packageNameFor: pkg).
	d at: 'printString' put: (self safePrint: pkg).
	(pkg respondsTo: #hasUnsavedChanges) ifTrue: [ d at: 'dirty' put: pkg hasUnsavedChanges ].
	(pkg respondsTo: #fullFileName) ifTrue: [ d at: 'path' put: pkg fullFileName asString ].
	^d! !

!CuisAgentBridge methodsFor: 'packages' stamp: 'ai 4/24/2026 12:00'!
pkgListArgs: args
	| d arr |
	arr := OrderedCollection new.
	self installedPackages do: [ :pkg | arr add: (self packageInfoFor: pkg) ].
	d := self okResponse.
	d at: 'packages' put: arr asArray.
	^d! !

!CuisAgentBridge methodsFor: 'packages' stamp: 'ai 4/24/2026 12:00'!
pkgDirtyArgs: args
	| d arr |
	arr := OrderedCollection new.
	self installedPackages do: [ :pkg |
		((pkg respondsTo: #hasUnsavedChanges) and: [ pkg hasUnsavedChanges ]) ifTrue: [ arr add: (self packageInfoFor: pkg) ] ].
	d := self okResponse.
	d at: 'dirty' put: arr asArray.
	^d! !

!CuisAgentBridge methodsFor: 'packages' stamp: 'ai 4/24/2026 12:00'!
pkgLoadArgs: args
	| package d |
	package := args at: 'package' ifAbsent: [ '' ].
	[ self runHeadless: [
		[ ((package endsWith: '.pck.st') or: [ package includes: $/ ])
			ifTrue: [ CodePackageFile installPackage: package asFileEntry ]
			ifFalse: [ Feature require: package ] ]
			on: UndeclaredVariableReference, UndeclaredVariableWarning
			do: [ :ex | ex resume ] ].
	d := self okResponse.
	d at: 'package' put: package.
	^d ]
		on: Exception
		do: [ :ex | ^self captureException: ex ]! !

!CuisAgentBridge methodsFor: 'packages' stamp: 'ai 4/24/2026 12:00'!
ensureSavePathFor: aPackage
	"Assign a fullFileName so CodePackage>>save does not block on a modal prompt in headless mode. Uses the project packages/ directory, falling back to Cuis's newPackagesDirectory."
	| saveDir |
	((aPackage respondsTo: #fullFileName) and: [ (aPackage respondsTo: #fullFileName:) ]) ifFalse: [ ^self ].
	(aPackage respondsTo: #packageFileName) ifFalse: [ ^self ].
	saveDir := DirectoryEntry currentDirectory / 'packages'.
	(saveDir exists and: [ saveDir isDirectory ]) ifFalse: [ saveDir := DirectoryEntry newPackagesDirectory ].
	aPackage fullFileName: (saveDir // aPackage packageFileName) pathName! !

!CuisAgentBridge methodsFor: 'packages' stamp: 'ai 4/24/2026 12:00'!
pkgSaveArgs: args
	| all package d saved |
	all := args at: 'all' ifAbsent: [ false ].
	saved := OrderedCollection new.
	[ all
		ifTrue: [ self installedPackages do: [ :pkg | (pkg respondsTo: #save) ifTrue: [ self ensureSavePathFor: pkg. self runHeadless: [ pkg save ]. saved add: (self packageNameFor: pkg) ] ] ]
		ifFalse: [
			package := self packageNamed: (args at: 'package' ifAbsent: [ '' ]).
			package ifNil: [ ^self errorResponse: 'package not found' ].
			(package respondsTo: #save) ifFalse: [ ^self unsupportedResponse: 'package does not understand save' ].
			self ensureSavePathFor: package.
			self runHeadless: [ package save ].
			saved add: (self packageNameFor: package) ].
	d := self okResponse.
	d at: 'saved' put: saved asArray.
	^d ]
		on: Exception
		do: [ :ex | ^self captureException: ex ]! !

!CuisAgentBridge methodsFor: 'packages' stamp: 'ai 4/24/2026 12:00'!
pkgPathArgs: args
	| package d |
	package := self packageNamed: (args at: 'package' ifAbsent: [ '' ]).
	package ifNil: [ ^self errorResponse: 'package not found' ].
	d := self okResponse.
	d at: 'package' put: (self packageNameFor: package).
	(package respondsTo: #fullFileName)
		ifTrue: [ d at: 'path' put: package fullFileName asString ]
		ifFalse: [ d at: 'path' put: '' ].
	^d! !

!CuisAgentBridge methodsFor: 'packages' stamp: 'ai 4/24/2026 12:00'!
pkgDepsArgs: args
	| package d deps |
	package := self packageNamed: (args at: 'package' ifAbsent: [ '' ]).
	package ifNil: [ ^self errorResponse: 'package not found' ].
	deps := #().
	(package respondsTo: #requires) ifTrue: [ deps := package requires ].
	d := self okResponse.
	d at: 'package' put: (self packageNameFor: package).
	d at: 'dependencies' put: (self stringArrayFrom: deps).
	^d! !

!CuisAgentBridge methodsFor: 'testing' stamp: 'ai 4/24/2026 12:00'!
testRunArgs: args
	| target class suite result d |
	target := args at: 'target' ifAbsent: [ '' ].
	[ target isEmpty ifTrue: [
		^self responseForResult: (Compiler evaluate: 'TestResult new') retain: false ].
	class := self classNamed: target.
	class ifNil: [ | evalArgs | evalArgs := Dictionary new. evalArgs at: 'code' put: target. evalArgs at: 'retain' put: false. ^self evaluateArgs: evalArgs ].
	(class respondsTo: #buildSuite) ifFalse: [ ^self errorResponse: 'target class has no suite' ].
	suite := class buildSuite.
	result := suite run.
	d := self okResponse.
	d at: 'target' put: target.
	d at: 'result' put: (self safePrint: result).
	(result respondsTo: #passed) ifTrue: [ d at: 'passed' put: result passed ].
	(result respondsTo: #failures) ifTrue: [ d at: 'failures' put: (self safePrint: result failures) ].
	(result respondsTo: #errors) ifTrue: [ d at: 'errors' put: (self safePrint: result errors) ].
	^d ]
		on: Exception
		do: [ :ex | ^self captureException: ex ]! !

!CuisAgentDebugSession class methodsFor: 'instance creation' stamp: 'ai 4/24/2026 12:00'!
id: idString exception: anException process: aProcess
	^self new id: idString exception: anException process: aProcess! !

!CuisAgentDebugSession methodsFor: 'initialization' stamp: 'ai 4/24/2026 12:00'!
id: idString exception: anException process: aProcess
	id := idString.
	exception := anException.
	process := aProcess.
	createdAt := DateAndTime now.
	state := 'captured'.
	context := nil.
	(anException respondsTo: #signalerContext) ifTrue: [
		context := anException signalerContext ].
	(context isNil or: [ context sender isNil ]) ifTrue: [
		(anException respondsTo: #signalContext) ifTrue: [
			| alt |
			alt := anException signalContext.
			(alt notNil and: [ alt sender notNil ]) ifTrue: [ context := alt ] ] ].
	context ifNil: [ context := thisContext ].
	^self! !

!CuisAgentDebugSession methodsFor: 'accessing' stamp: 'ai 4/24/2026 12:00'!
id
	^id! !

!CuisAgentDebugSession methodsFor: 'accessing' stamp: 'ai 4/24/2026 12:00'!
state
	^state! !

!CuisAgentDebugSession methodsFor: 'accessing' stamp: 'ai 4/24/2026 12:00'!
exceptionString
	^[ exception printString ] on: Error do: [ :ex | '<exception print failed>' ]! !

!CuisAgentDebugSession methodsFor: 'contexts' stamp: 'ai 4/24/2026 12:00'!
contextAt: index
	| current i |
	current := context.
	i := 0.
	[current notNil and: [ i < index ]] whileTrue: [ current := current sender. i := i + 1 ].
	^current! !

!CuisAgentDebugSession methodsFor: 'contexts' stamp: 'ai 4/24/2026 12:00'!
summaryForContext: aContext index: index
	| d receiver method selector className |
	d := Dictionary new.
	d at: 'index' put: index.
	aContext ifNil: [ d at: 'missing' put: true. ^d ].
	receiver := [ aContext receiver ] on: Error do: [ :ex | nil ].
	method := [ aContext method ] on: Error do: [ :ex | nil ].
	selector := method ifNil: [ '' ] ifNotNil: [ (method respondsTo: #selector) ifTrue: [ method selector asString ] ifFalse: [ method printString ] ].
	className := receiver ifNil: [ '' ] ifNotNil: [ receiver class name asString ].
	d at: 'receiverClass' put: className.
	d at: 'receiver' put: ([ receiver printString ] on: Error do: [ :ex | '<receiver print failed>' ]).
	d at: 'selector' put: selector.
	d at: 'method' put: (method ifNil: [ '' ] ifNotNil: [ method printString ]).
	^d! !

!CuisAgentDebugSession methodsFor: 'contexts' stamp: 'ai 4/24/2026 12:00'!
stackSummaries
	| arr current index |
	arr := OrderedCollection new.
	current := context.
	index := 0.
	[current notNil and: [ index < 80 ]] whileTrue: [
		arr add: (self summaryForContext: current index: index).
		current := current sender.
		index := index + 1 ].
	^arr asArray! !

!CuisAgentDebugSession methodsFor: 'contexts' stamp: 'ai 4/24/2026 12:00'!
stackPreview
	| arr |
	arr := OrderedCollection new.
	self stackSummaries do: [ :each |
		arr size < 8 ifTrue: [ arr add: ((each at: 'receiverClass' ifAbsent: [ '' ]), '>>', (each at: 'selector' ifAbsent: [ '' ])) ] ].
	^arr asArray! !

!CuisAgentDebugSession methodsFor: 'contexts' stamp: 'ai 4/24/2026 12:00'!
topFrameSummary
	^self summaryForContext: context index: 0! !

!CuisAgentDebugSession methodsFor: 'contexts' stamp: 'ai 4/24/2026 12:00'!
frameSummaryAt: index
	^self summaryForContext: (self contextAt: index) index: index! !

!CuisAgentDebugSession methodsFor: 'contexts' stamp: 'ai 4/24/2026 12:00'!
sourceAt: index
	| ctx method |
	ctx := self contextAt: index.
	ctx ifNil: [ ^'' ].
	method := [ ctx method ] on: Error do: [ :ex | nil ].
	method ifNil: [ ^'' ].
	(method respondsTo: #sourceCode) ifTrue: [ ^method sourceCode ].
	(method respondsTo: #getSource) ifTrue: [ ^method getSource ].
	^method printString! !

!CuisAgentDebugSession methodsFor: 'contexts' stamp: 'ai 4/24/2026 12:00'!
varsAt: index
	| ctx d receiver temps |
	ctx := self contextAt: index.
	d := Dictionary new.
	ctx ifNil: [ ^d ].
	receiver := [ ctx receiver ] on: Error do: [ :ex | nil ].
	d at: 'receiver' put: ([ receiver printString ] on: Error do: [ :ex | '<receiver print failed>' ]).
	d at: 'receiverClass' put: (receiver ifNil: [ '' ] ifNotNil: [ receiver class name asString ]).
	temps := OrderedCollection new.
	(ctx respondsTo: #tempNames) ifTrue: [
		1 to: ctx tempNames size do: [ :i |
			| item value |
			item := Dictionary new.
			item at: 'name' put: (ctx tempNames at: i) asString.
			value := [ ctx tempAt: i ] on: Error do: [ :ex | '<unavailable>' ].
			item at: 'value' put: ([ value printString ] on: Error do: [ :ex | '<print failed>' ]).
			temps add: item ] ].
	d at: 'temps' put: temps asArray.
	^d! !

!CuisAgentDebugSession methodsFor: 'actions' stamp: 'ai 4/24/2026 12:00'!
evaluate: code at: index
	| ctx receiver |
	ctx := self contextAt: index.
	ctx ifNil: [ ^Compiler evaluate: code ].
	receiver := [ ctx receiver ] on: Error do: [ :ex | nil ].
	(Compiler respondsTo: #evaluate:in:to:notifying:ifFail:logged:) ifTrue: [
		^Compiler evaluate: code in: ctx to: receiver notifying: nil ifFail: [ self error: 'evaluation failed' ] logged: false ].
	^Compiler evaluate: code! !

!CuisAgentDebugSession methodsFor: 'actions' stamp: 'ai 4/24/2026 12:00'!
ok: messageString
	| d |
	d := Dictionary new.
	d at: 'status' put: 'ok'.
	d at: 'message' put: messageString.
	d at: 'debugger' put: id.
	^d! !

!CuisAgentDebugSession methodsFor: 'actions' stamp: 'ai 4/24/2026 12:00'!
unsupported: messageString
	| d |
	d := Dictionary new.
	d at: 'status' put: 'unsupported'.
	d at: 'message' put: messageString.
	d at: 'debugger' put: id.
	^d! !

!CuisAgentDebugSession methodsFor: 'actions' stamp: 'ai 4/24/2026 12:00'!
stepKind: kindString
	state := 'step-requested'.
	^self unsupported: ('step ', kindString, ' requires VM debugger process integration in this image')! !

!CuisAgentDebugSession methodsFor: 'actions' stamp: 'ai 4/24/2026 12:00'!
restartAt: index
	| ctx |
	ctx := self contextAt: index.
	ctx ifNil: [ ^self unsupported: 'frame not found' ].
	(ctx respondsTo: #restart) ifTrue: [
		[ ctx restart. state := 'restarted'. ^self ok: 'frame restart requested' ]
			on: Error
			do: [ :ex | ^self unsupported: ex printString ] ].
	^self unsupported: 'context does not understand restart'! !

!CuisAgentDebugSession methodsFor: 'actions' stamp: 'ai 4/24/2026 12:00'!
proceed
	(exception respondsTo: #isResumable) ifTrue: [
		exception isResumable ifTrue: [
			[ exception resume. state := 'proceeded'. ^self ok: 'exception resume requested' ]
				on: Error
				do: [ :ex | ^self unsupported: ex printString ] ] ].
	^self unsupported: 'exception is not resumable through this bridge path'! !

!CuisAgentDebugSession methodsFor: 'actions' stamp: 'ai 4/24/2026 12:00'!
abort
	process ifNotNil: [
		(process respondsTo: #terminate) ifTrue: [
			[ process terminate ] on: Error do: [ :ex | ex return ] ] ].
	state := 'aborted'.
	^self ok: 'process abort requested'! !
