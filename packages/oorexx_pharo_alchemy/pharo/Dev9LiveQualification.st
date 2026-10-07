"Pharo 12 live-runtime qualification for Alchemy. Uses a disposable class."
| cls obj before after value threw missing block blockValue identity |
cls := ShiftClassInstaller make: [ :builder |
    builder superclass: Object;
        name: #AlchemyDev9QualificationObject;
        package: 'Alchemy-ooRexx-Qualification' ].
obj := cls new.

"Passive discovery before and after live method installation."
before := obj respondsTo: #alchemyValue:.
cls compile: 'alchemyValue: x ^ x + 1'.
after := obj respondsTo: #alchemyValue:.
value := obj perform: #alchemyValue: with: 41.

"Existing-method exception must be distinguishable from missing dispatch."
threw := false.
cls compile: 'explode self error: ''dev9 boom'''.
[ obj perform: #explode ] on: Error do: [ :e | threw := true ].
missing := false.
[ obj perform: #notThere ] on: MessageNotUnderstood do: [ :e | missing := true ].

"Blocks remain live Smalltalk objects."
block := [ :x | x + 1 ].
blockValue := block value: 41.
identity := block == block.

Transcript
    show: 'DEV9 before=', before printString; cr;
    show: 'DEV9 after=', after printString; cr;
    show: 'DEV9 value=', value printString; cr;
    show: 'DEV9 exception=', threw printString; cr;
    show: 'DEV9 missing=', missing printString; cr;
    show: 'DEV9 blockValue=', blockValue printString; cr;
    show: 'DEV9 identity=', identity printString; cr.
Smalltalk snapshot: false andQuit: true.
