; P-Vars.asm
;
; Copyright (c) 2019, Dmitry Razumovsky (Svarov-RZM)
; You may distribute under the terms of BSD 2-Clause License
; as specified in the LICENSE.TXT file.
;
; >>>=== VARIABLE-SPECIFIC PROCEDURES ===<<<
; => Add variable to VARS buffer <=
; IN:
;       ESI = [POINTER] NAME.TYPE.ACTION.OPTIONS
;       EDI = [POINTER] Position in VARS to insert [PRESERVED]
; OUT:
;       AL = [BYTE] 0 - Fail (not enough space, not implemented), 1 - Success
;       ESI = [POINTER] ACTION section
ADD.NEW.VAR:

mov edx,edi

; Copy NAME to VARS
Call COPY.NT.STR

; Skip to TYPE
Call SKIP.CHAR.FORWARD
Call SKIP.CHAR.FORWARD.DST

; Copy TYPE to VARS
Call COPY.NT.STR

; Skip to ACTION in SRC
; Skip to DATA in DST (VARS)
Call SKIP.CHAR.FORWARD
Call SKIP.CHAR.FORWARD.DST

; Update end of VARS
mov [ebp-40],edi

A.N.V.RET:
mov al,1
mov edi,edx
Ret


; => Adjust variable array <=
; We check mode and length of the string and if it's
; longer than currently allocated, we expand VARS array
; IN:
;       [EBP-40] = [POINTER] End of VARS array
;       ESI = [POINTER] Data to add/replace [PRESERVED]
;       EDI = [POINTER] SIZE section in VARS
; OUT:
;       EDI = [POINTER] DATA section in VARS
ADJUST.VARIABLE.ARRAY:

; Preserve needed pointers
push esi
push edi

; Count the new string and convert it to BYTE counter
; We increment ECX to account for NULL-TERMINATOR
Call COUNT.STRING
inc ecx
Call CONVERT.LENGTH.TO.BYTES

; Save old length to EDX, new one to VARS
; We add DWORD to ECX because we place counter not only in the begin
; of the DATA section but also in the end too, so final result is: [SIZE]DATA[SIZE]
mov edx,[edi]
add ecx,C_DWORD
mov [edi],ecx

; Check if we're in the end of VARS
; if so, then no need to adjust
cmp [ebp-40],edi
je A.V.A.RET

; Check if we have to extend/collapse VARS array
sub ecx,edx
je A.V.A.RET; Same size, we are lucky
ja A.V.A.EXTEND

; Collapse array
A.V.A.COLLAPSE:

; EDX = Counter of old variable
; [EDI] = Counter of new variable
; ECX = Length we have to shorten VARS array to
sub edx,[edi]
xchg ecx,edx
push ecx

; Starting position where to collapse the memory
; COLLAPSE.MEMORY.BYTES works with ESI
mov esi,edi

; Skip SIZE section, now we point to DATA section
add esi,4

; EAX = End of VARS array but points to SIZE+DATA
; We have to skip DATA knowing its SIZE
mov eax,[ebp-40]
add eax,4; Skip SIZE
add eax,[eax-4]; Skip DATA

Call COLLAPSE.MEMORY.BYTES

; After memory collapse the end of VARS in [EBP-40]
; is not valid anymore, we have to fix it
pop ecx
mov eax,[ebp-40]
sub eax,ecx
mov [ebp-40],eax

jmp short A.V.A.RET

; Extend array
A.V.A.EXTEND:

; Save difference between current and new size
push ecx

; Prepare source and destination
; ESI = Pointer to current position, we skip SIZE section
; EDI = Pointer to the end of array
mov esi,edi
add esi,4
mov edi,[ebp-40]
add edi,4
add edi,[edi-4]

; Calculate how much we must extend array
; Save difference in EDX, we'll use it to correct
; the end of array after COLLAPSE.MEMORY.BYTES call
mov edx,ecx

; In ECX we get the difference in bytes between end of array and current position
; It's a counter for how much we have to extend our array
mov ecx,edi
sub ecx,esi

; We determine if length of new string is bigger than the WHOLE
; VARS array, in this case we have to use new string counter for expanding
cmp ecx,edx
jae A.V.A.COPY
; String counter is bigger, use it for expanding
xchg edx,ecx

; Copy the rest of array
A.V.A.COPY:
Call COPY.MEM.GENERAL

; EAX = End of VARS returned in EDI by COPY.MEM.GENERAL
mov eax,edi

; ECX = Calculate the length to collapse
sub ecx,[esp]
add esp,4

; ESI = Current position in VARS, again, we skip SIZE section
mov esi,[esp]
add esi,4

Call COLLAPSE.MEMORY.BYTES

; After memory expansion and collapse, the end of VARS in [EBP-40] is not valid anymore,
; we have to fix it. Earlier we saved a counter for that purpose in EDX
mov eax,[ebp-40]
add eax,edx
mov [ebp-40],eax

; Restore pointers and return
; We skip in EDI to point to DATA section
A.V.A.RET:

pop edi
pop esi
add edi,4

Ret


; => Compose variable <=
; We use this procedure to compose the variable structure
; in memory for MANAGE.VAR, e.g. VarName,T,=,123
; IN:
;       ESI = [POINTER] Name of the variable (NT string)
;       AX = [CHAR] TYPE
;       CX = [CHAR] ACTION
; OUT:
;       ESI = [POINTER] DATA section
COMPOSE.VARIABLE:

push edi
push ecx
push eax

; Determine if variable exists.
; If so, then we must omit TYPE
mov edi,[ebp-36]
Call SEARCH.VAR
push eax; Preserve flag for later comparison

; Add NAME
Call SKIP.NT.STRING

; Skip TYPE if variable exists
pop eax
cmp al,1
pop eax
je C.V.ADD.ACTION

; Add TYPE
mov [esi],ax
Call SKIP.CHAR.FORWARD
Call ADD.NULL.TERMINATOR
Call SKIP.CHAR.FORWARD

; Add ACTION
C.V.ADD.ACTION:
pop ecx
mov [esi],cx
Call SKIP.CHAR.FORWARD
Call ADD.NULL.TERMINATOR
Call SKIP.CHAR.FORWARD

pop edi

Ret


; => Get DBOX variable <=
; IN:
;       ESI = [POINTER] NAME of variable
; OUT:
;       ESI = [POINTER] DBOX structure
GET.DBOX.VARIABLE:

; Search variable
mov edi,[ebp-36]; VARS buffer
Call SEARCH.VAR
cmp al,1
jne G.D.V.RET.BAD

; Get pointer
Call SKIP.VAR.TO.DATA
mov esi,edi
jmp short G.D.V.RET

G.D.V.RET.BAD:
xor esi,esi

G.D.V.RET:

Ret


; => Get pointer to any variable's DATA <=
; IN:
;       ESI = [POINTER] NAME of variable
; OUT:
;       ESI = [POINTER] DATA section of requested variable or ZERO if failed
;       AX = [CHAR] Type of variable
GET.VARIABLE:

; Search variable
mov edi,[ebp-36]; VARS buffer
Call SEARCH.VAR
cmp al,1
jne G.V.RET.BAD

; Get pointer
Call SKIP.VAR.TO.DATA
mov esi,edi
jmp short G.V.RET

G.V.RET.BAD:
xor esi,esi

G.V.RET:

Ret


; => Get variable by type <=
; IN:
;       AX = [CHAR] Type of variable
;       ESI = [POINTER] NAME of variable
; OUT:
;       ESI = [POINTER] DATA section
;       ECX = [INT] Counter of DATA section
GET.VARIABLE.BY.TYPE:

; Save type and set up initial index
; EDI is a placeholder for next VARS pointer
push eax
push edi
mov edi,[ebp-36]; VARS buffer

; Search variable
G.V.B.T.LOOP:
Call SEARCH.VAR
cmp al,1
jne G.V.B.T.RET.BAD

; Get pointer to DATA and TYPE
; We must preserve EDI because it points to NAME in VARS
; This way SEARCH.VAR can continue searching futher
mov [esp],edi
Call SKIP.VAR.TO.DATA

; Check type and repeat search if not matched
mov edx,[esp+4]
cmp al,dl
je G.V.B.T.FIN
mov edi,[esp]
jmp short G.V.B.T.LOOP

; Get values
G.V.B.T.FIN:
mov ecx,[edi-4]
mov esi,edi
jmp short G.V.B.T.RET

G.V.B.T.RET.BAD:
xor esi,esi

G.V.B.T.RET:
add esp,8; Saved pointer to VARS and TYPE

Ret


; => Get LABEL variable <=
; IN:
;       ESI = [POINTER] NAME of variable
; OUT:
;       ESI = [POINTER] Position of the next argument or NULL if not found
;       ECX = [INT] Size of arguments
GET.LABEL.VARIABLE:

; Search variable
mov edi,[ebp-36]; VARS buffer
Call SEARCH.VAR
cmp al,1
jne G.L.V.RET.BAD

; Get pointer
Call SKIP.VAR.TO.DATA

; Check type
cmp al,'L'
jne EXIT

; Get values
mov ecx,[edi]
mov esi,[edi+4]
jmp short G.L.V.RET

G.L.V.RET.BAD:
xor esi,esi

G.L.V.RET:

Ret


; => Get MODE variable <=
; IN:
;       ESI = [POINTER] NAME of variable
; OUT:
;       ESI = [POINTER] DATA section
;       ECX = [INT] Counter of DATA section
GET.MODE.VARIABLE:

; Search variable
mov edi,[ebp-36]; VARS buffer
Call SEARCH.VAR
cmp al,1
jne G.M.V.RET.BAD

; Get pointer
Call SKIP.VAR.TO.DATA

; Check type
cmp al,'M'
jne EXIT

; Get values
mov ecx,[edi-4]
mov esi,edi
jmp short G.M.V.RET

G.M.V.RET.BAD:
xor esi,esi

G.M.V.RET:

Ret


; => Get pointer to the next variable <=
; IN:
;       EDI = [POINTER] VARS buffer
; OUT:
;       ESI = [POINTER] DATA section of requested variable or ZERO if failed
;       EDI = [POINTER] Next position in VARS buffer
;       AX = [CHAR] Type of variable
GET.NEXT.VARIABLE:

; See if we are in the end of VARS array
cmp edi,[ebp-40]
jae G.N.V.RET.BAD

; Skip NAME and TYPE of current variable
xchg esi,edi
Call SKIP.NT.STRING
mov ax,[esi]; TYPE
mov ecx,2
Call SKIP.WORDS
xchg esi,edi

; We are at variable's DATA
; Save to ESI and skip to next variable
mov esi,edi
add esi,C_DWORD; ESI = DATA section
add edi,[edi]
add edi,C_DWORD*2

jmp short G.N.V.RET

G.N.V.RET.BAD:
xor esi,esi

G.N.V.RET:

Ret


; => Get pointer to the previous variable <=
; IN:
;       EDI = [POINTER] VARs buffer
; OUT:
;       ESI = [POINTER] DATA section of requested variable or ZERO if failed
;       EDI = [POINTER] Next position in VARS buffer
;       AX = [CHAR] Type of variable
GET.PREVIOUS.VARIABLE:

; Return if we're out of VARS array
cmp edi,[ebp-36]
jbe G.P.V.RET.BAD

; Rewind to DATA section of the previous variable
sub edi,C_DWORD
sub edi,[edi]
push edi; Save DATA section

; Rewind to TYPE
sub edi,C_DWORD*2; SIZE+Separator
mov dx,[edi]

; Rewind to the first letter of the NAME section
sub edi,C_WORD*2; TYPE+Separator
xchg esi,edi
Call REWIND.NT.STRING
mov ecx,2
Call SKIP.CHARACTERS
xchg esi,edi

; We're at variable's NAME
; Restore DATA section and set TYPE in AX
mov ax,dx
pop esi
jmp short G.P.V.RET

G.P.V.RET.BAD:
xor esi,esi

G.P.V.RET:

Ret


; => Add new or change already existing variable <=
; IN:
;       ESI = [POINTER] Variable structure: NAME,TYPE [NEW] or NAME,ACTION,OPTIONS [CHANGE]
;       ACTION and OPTIONS depends on what matched PROCESS.*.VARIABLE procedure requires
; OUT:
;       AL = [BYTE] 0 - Fail (end of VARS), 1 - Added/Modified successfully
;       OTHER REGISTERS: Depends on PROCESS.*.VARIABLE
MANAGE.VAR:

; Split string
xor dh,dh
mov dl,','
Call SPLIT.STRING

; Search variable
mov edi,[ebp-36]; VARS buffer
Call SEARCH.VAR
test al,al
je C.V.RET; Hit the end of VARS array
cmp al,1
je C.V.ACTION

; Could not found - let's add a new one
Call ADD.NEW.VAR

jmp short C.V.ACT.SNAME

; Process action
C.V.ACTION:

; Skip NAME and TYPE in [SRC]
Call SKIP.NT.STRING

; Jump here if ADD.NEW.VAR procedure was called
C.V.ACT.SNAME:

; Skip NAME in [DST]
push esi
mov esi,edi
Call SKIP.NT.STRING; Skip NAME in EDI
mov edi,esi; EDI = Selected variable without NAME
pop esi; ESI = New data variable without NAME

; Call the appropriate action for numerical/string/etc variable
mov ax,[edi]; AX = Type
cmp al,'T'; Text
je C.V.A.T
cmp al,'N'; Numerical
je C.V.A.N
cmp al,'L'; Label
je C.V.A.L
cmp al,'D'; DBOX
je C.V.A.D
cmp al,'F'; Frame
je C.V.A.F
cmp al,'E'; Active element
je C.V.A.E
cmp al,'M'; Mode
je C.V.A.M
xor al,al
jmp short C.V.RET; Ignore unknown type

; Process text variable
C.V.A.T:
Call PROCESS.STRING.VARIABLE
jmp short C.V.RET.GOOD

; Process numerical variable
C.V.A.N:
Call PROCESS.NUMERICAL.VARIABLE
jmp short C.V.RET.GOOD

; Process label variable
C.V.A.L:
Call PROCESS.LABEL.VARIABLE
jmp short C.V.RET.GOOD

; Process DBOX variable
C.V.A.D:
Call PROCESS.DBOX.VARIABLE
jmp short C.V.RET.GOOD

; Process frame variable
C.V.A.F:
Call PROCESS.FRAME.VARIABLE
jmp short C.V.RET.GOOD

; Process active element variable
C.V.A.E:
Call PROCESS.ELEMENT.VARIABLE
jmp short C.V.RET.GOOD

; Process mode variable
C.V.A.M:
Call PROCESS.MODE.VARIABLE

; Added/Modified successfully
C.V.RET.GOOD:
mov al,1

C.V.RET:
Ret


; => Skip to DATA section in variable structure <=
; IN:
;       EDI = [POINTER] Name of variable in VARS buffer
; OUT:
;       EDI = [POINTER] DATA section
;       AX = [CHAR] TYPE of variable
SKIP.VAR.TO.DATA:

push esi

; Skip NAME, TYPE and SIZE
mov esi,edi
Call SKIP.NT.STRING
mov ax,[esi]
mov ecx,4
Call SKIP.WORDS
mov edi,esi

pop esi

Ret


; => Expand string variable <=
; IN:
;       ESI = [POINTER] String to expand, e.g. 'Text~Var~123'
; OUT:
;       ESI = [POINTER] Expanded string in DATA buffer
; DATA example:
;       Before~EXP~After
EXPAND.STR.VAR:

push esi; Save pointer to 'Before~EXP~After'

; Looking for variable symbol
xor dh,dh
mov dl,'~'; Indicates variable
Call SEARCH.CHAR.NT
test al,al
je E.S.V.RET
; ESI now points to '~EXP~After'

; Replacing the second variable symbol
push esi; This is the start point of where we'll expand the variable
add esi,2; ESI points to 'EXP~After'
mov ax,bx; Replace second symbol with NT
Call REPLACE.WORD.NT
test al,al
je E.S.V.RET.BAD; It's just one ~ symbol, not a variable
Call COUNT.STRING
push ecx; Save counter of variable's name
; ESI now points to '~EXP~After'

; Search and count the variable
mov edi,[ebp-36]; VARS buffer
Call SEARCH.VAR
cmp al,1
jne E.S.V.RET.BAD; No such variable

Call SKIP.VAR.TO.DATA

; Insert the new string from variable
pop ecx
add ecx,2; Don't forget two '~~' symbols
pop esi
; ECX = Counter: Variable's name
; ESI = Pointer: 'EXP.After'
; EDI = Pointer: Variable's data
Call COLLAPSE.NT.STRING
xchg esi,edi
Call INSERT.STRING
jmp short E.S.V.NEXT

E.S.V.RET.BAD:
add esp,8; Remove counter and temp pointer
pop esi
Ret

; Iterate all over again in case there's another variable
E.S.V.NEXT:
pop esi; Restore initial pointer
jmp EXPAND.STR.VAR

; No more vars, return
E.S.V.RET:
pop esi; Restore initial pointer
Ret


; => Process action on numerical variable <=
; IN:
;       ESI = [POINTER] Action for numerical variable
;               Example: =,10 or +,25
;       EDI = [POINTER] TYPE of currently selected variable
; OUT:
;       EAX = [INT] Result from CALCULATE.SIMPLE
PROCESS.NUMERICAL.VARIABLE:

; Get mode for CALCULATE.SIMPLE in EAX
Call ACQUIRE.TWO.CHARS

; Convert the number from binary to text type
cmp al,'C'
je P.A.O.V.N.CNV

; Save mode
push eax

; Get RHS
cmp [esi],bx
je P.N.V.LHS; Not specified
Call CONVERT.DECIMAL.STRING.TO.INTEGER
mov edx,eax; RHS

; Get LHS
P.N.V.LHS:
xchg esi,edi
mov ecx,2
Call SKIP.WORDS; Skip TYPE+SIZE
mov ecx,[esi+C_DWORD]; LHS

; Calculate
pop eax; AX = Mode
Call CALCULATE.SIMPLE

; Set size and value
mov dword [esi],C_DWORD; Start SIZE
add esi,C_DWORD
mov [esi],eax; Set new value
add esi,C_DWORD
mov dword [esi],C_DWORD; End SIZE

Ret

; Convert variable to text
P.A.O.V.N.CNV:

; ESI = Start of the new variable structure: NAME
push esi

; Compose variable for MANAGE.VAR
xor ax,ax
mov ax,'T'
xor cx,cx
mov cx,'='
Call COMPOSE.VARIABLE

; Get current numerical value
xchg esi,edi
mov ecx,2
Call SKIP.WORDS; Skip TYPE+SIZE
mov eax,[esi+C_DWORD]; LHS
xchg esi,edi
Call CONVERT.BIN.TO.STR

; Add new variable
pop esi
Call MANAGE.VAR

Ret


; => Process action on string variable <=
; IN:
;       ESI = [POINTER] Action for numerical variable
;                       Example: =,Text or (,Left
;       EDI = [POINTER] TYPE.DATA
; OUT:
;       EDI = [POINTER] Selected variable (DATA section)
PROCESS.STRING.VARIABLE:

; Get ACTION and skip TYPE
Call ACQUIRE.CHAR
Call SKIP.CHAR.FORWARD

; Save ACTION for ADD.TO.STRING
push eax

; Skip to DATA
; 4 words is for TYPE(WORD), DELIMETER(WORD) and SIZE(DWORD)
mov ecx,4
Call SKIP.CHARACTERS.DST

; Save pointer to DATA section
push edi

; Skip current string in source
push esi; Save start of string
Call SKIP.NT.STRING
push esi; Save position after the first string
xchg esi,edi

; Copy current string in destination
Call COUNT.STRING
Call COPY.CHARACTERS
Call ADD.NULL.TERMINATOR.DST

; Add to string
; We compute in source because destination may not have enough of space
pop edi; String to add
mov esi,[esp]; Where to add
mov eax,[esp+8]; ACTION
Call ADD.TO.STRING
mov [esp],edi; Replace original source with the new result

; Adjust array in destination to fit string in source
pop esi; Original source
pop edi; DATA section
sub edi,4; Back to SIZE
add esp,4; Remove ACTION from the stack
Call ADJUST.VARIABLE.ARRAY

; Save counter of DATA section to write after the end
mov ecx,[edi-C_DWORD]
push ecx

; Copy new string to VARS array
Call COUNT.STRING
Call COPY.CHARACTERS
Call ADD.NULL.TERMINATOR.DST
Call SKIP.CHAR.FORWARD.DST; Skip NT

; Write end SIZE
pop ecx
mov [edi],ecx

Ret


; => Process action on label variable <=
; IN:
;       ESI = [POINTER] Label string
;       EDI = [POINTER] TYPE.DATA
; OUT:
;       EDI = [POINTER] Selected variable (DATA section)
PROCESS.LABEL.VARIABLE:

; Get ACTION and skip TYPE
Call ACQUIRE.CHAR
Call SKIP.CHAR.FORWARD

; Skip to DATA section
; 4 words is for TYPE(WORD), DELIMETER(WORD) and SIZE(DWORD)
mov ecx,4
Call SKIP.CHARACTERS.DST

; Add SIZE
; It's equal to Size of arguments + Pointer to current position
mov dword [edi-4],8

; Add new pointer for procedure/label
mov eax,[esi]
mov [edi],eax

; Add argument size
add esi,C_POINTER
add edi,C_POINTER
mov eax,[esi]
mov [edi],eax

; Add end SIZE
add edi,C_DWORD
mov dword [edi],8

Ret


; => Process action on DBOX variable <=
; IN:
;       ESI = [POINTER] DBOX structure in binary form
;       EDI = [POINTER] TYPE.DATA
; OUT:
;       EDI = [POINTER] Selected variable (DATA section)
PROCESS.DBOX.VARIABLE:

; Get ACTION and skip TYPE
Call ACQUIRE.CHAR
Call SKIP.CHAR.FORWARD

; Skip to DATA section
; 4 words is for TYPE(WORD), DELIMETER(WORD) and SIZE(DWORD)
mov ecx,4
Call SKIP.CHARACTERS.DST

; Add PRE SIZE
; DBOX is 8 bytes long
mov dword [edi-4],8

; Add DBOX values
mov ax,[esi]; X left
mov [edi],ax
mov ax,[esi+2]; X right
mov [edi+2],ax
mov ax,[esi+4]; Y top
mov [edi+4],ax
mov ax,[esi+6]; Y bottom
mov [edi+6],ax

; Add POST SIZE
mov dword [edi+8],8

Ret


; => Process action on ELEMENT variable <=
; IN:
;       ESI = [POINTER] DBOX + Label string
;       EDI = [POINTER] TYPE.DATA
; OUT:
;       EDI = [POINTER] Selected variable (DATA section)
PROCESS.ELEMENT.VARIABLE:

; Get ACTION and skip TYPE
Call ACQUIRE.CHAR
Call SKIP.CHAR.FORWARD

; Skip to DATA section
; 4 words is for TYPE(WORD), DELIMETER(WORD) and SIZE(DWORD)
mov ecx,4
Call SKIP.CHARACTERS.DST

; Add SIZE
; DBOX is 8 bytes long
; We save EDI because we must add procedure length to it later
mov dword [edi-4],8
push edi

; Copy DBOX values
mov ax,[esi]; X left
mov [edi],ax
mov ax,[esi+2]; X right
mov [edi+2],ax
mov ax,[esi+4]; Y top
mov [edi+4],ax
mov ax,[esi+6]; Y bottom
mov [edi+6],ax

; Copy the string that indicates procedure for active element
add edi,8
add esi,8
Call COPY.NT.STR

; Add procedure string size
mov edi,[esp]
mov eax,2
Call MULTIPLY.INTEGER
add eax,C_WORD; String+NT
add [edi-4],eax; Resulting size: DBOX+Procedure string

; Set POST SIZE
mov eax,[edi-4]
add edi,eax
mov [edi],eax

; Restore pointer to DATA section
pop edi

Ret


; => Process action on FRAME variable <=
; IN:
;       ESI = [POINTER] Drawing elements, like *,-,*,:, ,:,#,-,#
;       EDI = [POINTER] TYPE.DATA
; OUT:
;       EDI = [POINTER] Selected variable (DATA section)
PROCESS.FRAME.VARIABLE:

; Get ACTION and skip TYPE
Call ACQUIRE.CHAR
Call SKIP.CHAR.FORWARD

; Skip to DATA
; 4 words is for TYPE(WORD), DELIMETER(WORD) and SIZE(DWORD)
mov ecx,4
Call SKIP.CHARACTERS.DST

; Skip SIZE for now because frame is a dynamic structure
push edi
mov dword [edi-4],ebx

; Frame is constructed from 9 NT strings
; So we iterate 9 times and add those strings as well as counting resulting structure
mov eax,P.F.V.LOOP
mov ecx,9
Call LOOP.TIMES

; Convert size in words to bytes
pop esi
mov ecx,[esi-4]
mov eax,2
Call MULTIPLY.INTEGER

; Save PRE size and POST size
mov [esi-4],eax
mov [edi],eax

Ret

; CALLBACK: Process frame structure
P.F.V.LOOP:

; Copy string and get to the next position
Call COPY.NT.STR
Call SKIP.CHAR.FORWARD
Call SKIP.CHAR.FORWARD.DST

; Update counter
inc ecx; Account for null-terminator
mov eax,[esp+16]
add [eax-4],ecx

mov al,1

Ret


; => Process action on MODE variable <=
; IN:
;       ESI = [POINTER]: M_SIZE bytes of modes
;       EDI = [POINTER] TYPE.DATA
; OUT:
;       EDI = [POINTER] Selected variable (DATA section)
PROCESS.MODE.VARIABLE:

; Get ACTION and skip TYPE
Call ACQUIRE.CHAR
Call SKIP.CHAR.FORWARD

; Skip to DATA
; 4 words is for TYPE(WORD), DELIMETER(WORD) and SIZE(DWORD)
mov ecx,4
Call SKIP.CHARACTERS.DST

; Add PRE SIZE of variable
mov dword [edi-4],M_SIZE

; Copy flags to VARS
mov ecx,M_SIZE/2
Call COPY.MEM.WORDS

; Add POST size
mov dword [edi],M_SIZE

Ret


; => Search variable in VARS buffer <=
; IN:
;       ESI = [POINTER] Variable's name [PRESERVED]
;       EDI = [POINTER] VARS buffer
; OUT:
;       AL = [BYTE] 1 - Found, 0 - End of array, 2 - Not found
;       EDI = [POINTER] NAME of variable or an empty space after the last variable if not found
SEARCH.VAR:

push esi; Preserve variable's name

; Prepare
Call COUNT.STRING; Count variable's name
inc ecx; NT included
push ecx; Save counter

; Loop through VARS buffer
S.V.LOOP:

; See if we are in the end of array
cmp edi,[ebp-40]
jae S.V.RET.NF

; Compare against current variable
; If COMPARE.CHARS returns TRUE then we found it
mov ecx,[esp]
Call COMPARE.CHARS
test al,al
jne S.V.RET.GOOD

; Skip NAME and TYPE of current variable
xchg esi,edi
Call SKIP.NT.STRING
mov ecx,2
Call SKIP.WORDS
xchg esi,edi

; We're at variable's SIZE section
; From here we can skip to the next variable
add edi,[edi]
add edi,C_DWORD*2

jmp short S.V.LOOP

; Variable is not found
S.V.RET.NF:
mov al,2
jmp short S.V.RET

; Variable is found
S.V.RET.GOOD:
; AL is already 1 [set by COMPARE.CHARS]

S.V.RET:
add esp,4; Remove string counter
pop esi; Restore structure pointer
Ret