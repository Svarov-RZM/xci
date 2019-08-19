; P-Text.asm
;
; Copyright (c) 2019, Dmitry Razumovsky (Svarov-RZM)
; You may distribute under the terms of BSD 2-Clause License
; as specified in the LICENSE.TXT file.
;
; >>>=== TEXT-SPECIFIC PROCEDURES ===<<<
; => Add null-terminator to current position [SRC] <=
; IN:
;       ESI = [POINTER] Where to insert NT
ADD.NULL.TERMINATOR:

mov [esi],bx

Ret


; => Add null-terminator to current position [DST] <=
; IN:
;       ESI = [POINTER] Where to insert NT
ADD.NULL.TERMINATOR.DST:

mov [edi],bx

Ret


; => Add one string to another <=
; IN:
;       AX = [CHAR] Indicates mode:
;               '=' = Replace existing string with the new one
;               '(' = Add new string to the left side of existing one
;               ')' = Add new string to the right side of existing one
;       EDI = [POINTER] LHS: String [PRESERVED]
;       ESI = [POINTER] RHS: String to be added [PRESERVED]
; OUT:
;       EAX = [POINTER] End of copied string in DST buffer
ADD.TO.STRING:

push esi
push edi

; Check action
cmp al,'='
je A.T.S.REP
cmp al,'('
je A.T.S.LEFT
cmp al,')'
je A.T.S.RIGHT
jmp short A.T.S.RET; Unknown action

; Replace
A.T.S.REP:
Call COPY.NT.STR
jmp short A.T.S.RET

; Add to left
A.T.S.LEFT:
Call INSERT.STRING
jmp short A.T.S.RET

; Add to right
A.T.S.RIGHT:
xchg esi,edi
Call SKIP.NT.STRING
Call REWIND.CHAR.DST; Return to NT
xchg esi,edi
Call INSERT.STRING

; Finalizing
A.T.S.RET:
mov eax,edi
pop edi
pop esi
Ret


; => Collapse NT string <=
; Collapses a string by a specified number of characters
; IN:
;       ESI = [POINTER] String to collapse
;       ECX = [INT] Number of characters to exclude from string
; OUT:
;       ESI = [POINTER] Collapsed string
COLLAPSE.NT.STRING:

push edi; Preserve EDI
push esi; Preserve ESI

mov edi,esi
add esi,ecx
add esi,ecx
cmp [esi],bx
jne C.N.S.COPY
; We remove the whole string if there's nothing to collapse
mov [edi],ebx
jmp short C.N.S.RET

; EDI = Pointer: String to collapse
; ESI = Pointer: Skipped characters
C.N.S.COPY:
Call COPY.NT.STR

C.N.S.RET:
pop esi; Restore ESI
pop edi; Restore EDI

Ret


; => Convert different code pages to UTF-16 <=
; IN:
;       ESI = [POINTER] Bytes to convert
;       EDI = [POINTER] Where to save converted string
;       AL = [BYTE] Mode:
;               A = Convert from ANSI
;               O = Convert from OEM
;               U = Convert from UTF-8
; OUT:
;       ECX = [INT] Numbers of characters copied to DST buffer
CONVERT.BYTES.TO.WIDECHAR:

; Compare mode
cmp al,'A'
je C.B.T.W.MA
cmp al,'O'
je C.B.T.W.MO
cmp al,'U'
je C.B.T.W.MU
jmp C.B.T.W.RET; Unknown mode

; Process mode
C.B.T.W.MA:; ANSI
mov eax,CP_ACP
jmp short C.B.T.W.CALL

C.B.T.W.MO:; OEM
mov eax,CP_OEMCP
jmp short C.B.T.W.CALL

C.B.T.W.MU:; UTF-8
mov eax,CP_UTF8
jmp short C.B.T.W.CALL

; Converting
C.B.T.W.CALL:
push dword [ebp-16];6; Size of our buffer
push edi;5; Pointer to destination buffer
push -1;4; Count string for us, please
push esi;3; Pointer to source buffer
push ebx;2; Do a MB_PRECOMPOSED conversation
push eax;1; Convert from ? code page
Call [MultiByteToWideChar]
mov ecx,eax; Number of characters written

; Clear trash
mov eax,edi; Save destination buffer
Call SKIP.CHARACTERS.DST
mov [edi],ebx
mov edi,eax; Restore destination buffer

C.B.T.W.RET:
Ret


; => Convert string length to byte counter <=
; IN:
;       ECX = [INT] Chars
; OUT:
;       ECX = [INT] Bytes
CONVERT.LENGTH.TO.BYTES.UTF16:
CONVERT.LENGTH.TO.BYTES:; Alias

mov eax,2; Multiplier
Call MULTIPLY.INTEGER

xchg eax,ecx

Ret


; => Copy null terminated string <=
; IN:
;       ESI = [POINTER] String to copy
;       EDI = [POINTER] Copy where
; OUT:
;       ESI = [POINTER] End of initial string [points to NT]
;       EDI = [POINTER] End of copied string [points to NT]
;       EAX = [POINTER] Start of copied string
;       ECX = [INT] String size
COPY.NT.STR:

; Count string and return if it has zero size
Call COUNT.STRING.UTF16
test ecx,ecx
je C.NT.S.RET

push ecx
Call COPY.MEM.WORDS
pop ecx

xchg esi,edi
Call ADD.NULL.TERMINATOR
xchg esi,edi

C.NT.S.RET:
Ret


; => Count NULL-terminated UTF-16 string <=
; IN:
;       ESI = [POINTER] Buffer with string to count
; OUT:
;       EAX = [POINTER] End of counted string
;       ECX = [INT] Length of the string WITHOUT NULL-Terminator
COUNT.STRING.UTF16:
COUNT.STRING:; Alias

xor ecx,ecx

; Count until NULL terminator
C.S.U16.LOOP:
mov ax,[esi]; Working with UTF-16 characters, so 1 char = 2 bytes (actually wrong)
test ax,ax
je C.S.U16.FIN; Found NULL-terminator
inc ecx; +1 char
add esi,2; Next char
jmp short C.S.U16.LOOP

; Finalizing
C.S.U16.FIN:
mov eax,esi; EAX = End of string we just counted
sub esi,ecx; Begin of the string: 2 times because each char = 2 bytes
sub esi,ecx

Ret


; => Get summarized length of two NT strings <=
; IN:
;       ESI = [POINTER] First string [PRESERVED]
;       EDI = [POINTER] Second string [PRESERVED]
; OUT:
;       ECX = [INT] Summarized length
;       EAX = [INT] Length of the first string
GET.LENGTH.OF.TWO.STRINGS:

; Get length of the first string
Call COUNT.STRING.UTF16

; Save counter and switch pointers
push ecx
xchg edi,esi

; Get length of second string and restore first counter
Call COUNT.STRING.UTF16
pop eax

; Get sum and return pointers to default state
add ecx,eax
xchg edi,esi

Ret


; => Find next argument in array <=
; IN:
;       AX = [CHAR] Argument to look for
;       ESI = [POINTER] Arguments array
;       ECX = [INT] Rest of arguments array
FIND.ARGUMENT:

push eax

; Look for the next argument
; Return 0 if no more or process further
; DX = Char if found
F.A.LOOP:
Call SEARCH.NEXT.ARGUMENT
test al,al
je F.A.RET.BAD

; Check for match, we return 1 if matched
cmp dx,[esp]
je F.A.RET.GOOD

; Check next argument
jmp short F.A.LOOP

F.A.RET.GOOD:
mov al,1
jmp short F.A.RET

F.A.RET.BAD:
xor al,al

F.A.RET:
add esp,4

Ret


; => Insert string <=
; Inserts a string in-place of another one extending/descending it
; IN:
;       ESI = [POINTER] What to insert
;       EDI = [POINTER] Where to insert [PRESERVED]
INSERT.STRING:

; Preserve pointers
sub esp,4
push esi
push edi

; Count string in SOURCE
; If it has zero-length, we return
Call COUNT.STRING.UTF16
test ecx,ecx
je I.S.RET.PREMATURELY

; Save SOURCE counter to EDX
mov edx,ecx

; Count string in DESTINATION
xchg esi,edi
Call COUNT.STRING.UTF16
; Save DESTINATION counter on stack
mov [esp+8],ecx

; Let's check if DESTINATION string is lower/greater than SOURCE
mov eax,ecx
sub eax,edx
je I.S.ADD; Equal
jb I.S.ADD; Lower

; DESTINATION string is greater, we have to extend
Call SKIP.NT.STRING
Call REWIND.CHAR.DST; Return to NT
jmp short I.S.COPY

; Expanded string is greater
I.S.ADD:
xchg ecx,edx; ECX = Counter of SOURCE string
Call SKIP.CHARACTERS
xchg ecx,edx

; Expand SOURCE
; ESI = Copy from
; EDI = Copy to
I.S.COPY:
xchg esi,edi
mov esi,[esp]
Call COPY.NT.STR
Call ADD.NULL.TERMINATOR.DST

; Copy new string
pop edi; DESTINATION
pop esi; SOURCE
mov ecx,edx; ECX = Counter: SOURCE
Call COPY.MEM.WORDS
xchg esi,eax

; Collapse left over space if needed
pop ecx
sub ecx,edx
jb I.S.RET

push esi
xchg edx,ecx
Call SKIP.CHARACTERS
xchg edx,ecx
Call COLLAPSE.NT.STRING
pop esi

I.S.RET:
Ret

; We hit this if we were supplied a NULL length string in SOURCE
I.S.RET.PREMATURELY:
pop edi
pop esi
add esp,4
Ret


; => Process string with embedded (binary) characters <=
; IN:
;       ESI = [POINTER] Complex string [PRESERVED]
PROCESS.COMPLEX.STRING:

push edi
push esi

; Looking for '[' symbol
P.C.S.LOOP:
xor dh,dh
mov dl,'['; Indicates embedded char
Call SEARCH.CHAR.NT
test al,al
je P.C.S.RET; No embedded chars - return

; Check for exclude symbol
mov ecx,1
Call ACQUIRE.CHAR.BACKWARDS.AT
cmp ax,[ebp-4]
je P.C.S.SKIP; Skip excluded string
mov edi,esi; EDI = Pointer: [
Call SKIP.CHAR.FORWARD
jmp short P.C.S.KEY

; Skip excluded set
P.C.S.SKIP:
Call REWIND.CHAR.DST
mov ecx,1
Call COLLAPSE.NT.STRING
Call SKIP.CHAR.FORWARD
jmp short P.C.S.LOOP

; Check for key-symbol
P.C.S.KEY:
Call ACQUIRE.CHAR
cmp al,'n'
je P.C.S.NL; New line
cmp al,'d'
je P.C.S.NUM; Dec number
cmp al,'h'
je P.C.S.NUM; Hex number
jmp short P.C.S.KEY; Loop until end of pattern

; Insert new line
P.C.S.NL:

; Skip back at the start of [n]
Call REWIND.CHAR.DST
Call REWIND.CHAR.DST
mov edi,esi

; Remove '[n]'
mov ecx,3
Call COLLAPSE.NT.STRING

; Insert new line
mov esi,NewLine
Call INSERT.STRING
mov esi,edi
jmp short P.C.S.LOOP

; Insert dec/hex number
P.C.S.NUM:

push eax; Save mode

; Replace ']' symbol
xor dh,dh
mov dl,']'; Indicates END of embedded char
mov ax,bx; Replace with NULL
Call REPLACE.WORD.NT
test al,al
je P.C.S.POP; Not an embedded char - continue
pop eax; Mode: 'd' or 'h'
push ecx; ECX = Counter: Words from ESI to where replace occurred

; Convert number
cmp al,'d'
jne P.C.S.N.HEX
Call CONVERT.DECIMAL.STRING.TO.INTEGER
jmp short P.C.S.N.SAVE
P.C.S.N.HEX:
Call CONVERT.HEXADECIMAL.STRING.TO.INTEGER
P.C.S.N.SAVE:
mov [edi],ax

; Skip character that we just wrote
mov esi,edi
Call SKIP.CHAR.FORWARD

; Correct rest of the string
pop ecx
inc ecx; Skip '[' char
Call SKIP.CHARACTERS
mov [esi],cx; HACK: Replace NT so COLLAPSE.NT.STRING can count string correctly
Call SKIP.CHARACTERS.BACKWARDS
inc ecx; Add ']' char also
Call COLLAPSE.NT.STRING
jmp P.C.S.LOOP

; Clear temp stack and continue
P.C.S.POP:
add esp,4
jmp P.C.S.LOOP

; Returning
P.C.S.RET:
pop esi
pop edi
Ret


; => Process text comparison <=
; IN:
;       EAX = [DWORD] Type: eq/ne/gt/etc
;       ESI = [POINTER] LHS string [PRESERVED]
;       EDI = [POINTER] RHS string [PRESERVED]
; OUT:
;       AL = [BYTE] TRUE/FALSE
PROCESS.TEXT.COMPARISON:

; Optimization. ESI should be counted for all comparison types
xchg edx,eax; Save type
Call COUNT.STRING.UTF16
inc ecx; Count NT too
xchg edx,eax

; Check type
cmp eax,PREFIX_EQU
je P.T.C.EQU
cmp eax,PREFIX_NEQ
je P.T.C.NEQ
cmp eax,PREFIX_GEQ
je P.T.C.GEQ
cmp eax,PREFIX_LEQ
je P.T.C.LEQ
cmp eax,PREFIX_GTR
je P.T.C.GTR
cmp eax,PREFIX_LSS
je P.T.C.LSS

; Check if strings are equal
P.T.C.EQU:
Call COMPARE.CHARS
test al,al
jne P.T.C.RET.GOOD
jmp short P.T.C.RET.BAD

; Check if strings are different
P.T.C.NEQ:
Call COMPARE.CHARS
test al,al
je P.T.C.RET.GOOD
jmp short P.T.C.RET.BAD

; Check if counter of LHS string GEQ counter of RHS string
P.T.C.GEQ:
mov edx,ecx; EDX = Counter: LHS
xchg esi,edi
Call COUNT.STRING.UTF16; ECX = Counter: RHS
xchg esi,edi; Back to original state
cmp edx,ecx
jge P.T.C.RET.GOOD
jmp short P.T.C.RET.BAD

; Check if counter of LHS string LEQ counter of RHS string
P.T.C.LEQ:
mov edx,ecx; EDX = Counter: LHS
xchg esi,edi
Call COUNT.STRING.UTF16; ECX = Counter: RHS
xchg esi,edi; Back to original state
cmp edx,ecx
jle P.T.C.RET.GOOD
jmp short P.T.C.RET.BAD

; Check if counter of LHS string GTR counter of RHS string
P.T.C.GTR:
mov edx,ecx; EDX = Counter: LHS
xchg esi,edi
Call COUNT.STRING.UTF16; ECX = Counter: RHS
xchg esi,edi; Back to original state
cmp edx,ecx
jg P.T.C.RET.GOOD
jmp short P.T.C.RET.BAD

; Check if counter of LHS string LSS counter of RHS string
P.T.C.LSS:
mov edx,ecx; EDX = Counter: LHS
xchg esi,edi
Call COUNT.STRING.UTF16; ECX = Counter: RHS
xchg esi,edi; Back to original state
cmp edx,ecx
jl P.T.C.RET.GOOD
jmp short P.T.C.RET.BAD

P.T.C.RET.GOOD:
mov al,1
jmp short P.T.C.RET

P.T.C.RET.BAD:
xor al,al

P.T.C.RET:
Ret


; => Register argument and data <=
; This procedure simplifies calling other MAIN procedures like PROCESS.*
; by dealing with setting up argument in memory. This actually is a dirty hack
; and should be removed in the future.
; IN:
;       AX = [CHAR] Specifies a known argument like 'L', 'T', etc.
;       ESI = [POINTER] Data source
;       EDI: [POINTER] Destination where resulting argument will be combined
REGISTER.ARGUMENT.AND.DATA:

; Add argument
mov [edi],ax
Call SKIP.CHAR.FORWARD.DST
Call ADD.NULL.TERMINATOR.DST
Call SKIP.CHAR.FORWARD.DST

; Add data for argument
Call COPY.NT.STR
Call SKIP.CHAR.FORWARD
Call SKIP.CHAR.FORWARD.DST
Call ADD.NULL.TERMINATOR.DST

Ret


; => Replace a word in NULL-TERMINATED string <=
; IN:
;       DX = [CHAR] Search this
;       AX = [CHAR] Replace with this
;       ESI = [POINTER] Search where [PRESERVED]
; OUT:
;       AL = [BYTE] 0 - Fail, !0 - Success
;       ECX = [INT] Chars from start to a place we replaced target
REPLACE.WORD.NT:
REPLACE.CHAR.NT:; Alias

push esi
push eax

; Search for word
Call SEARCH.WORD.NT
test al,al
je R.W.N.RET.BAD

; Now replace
mov eax,[esp]
mov [esi],ax
jmp short R.W.N.RET.GOOD

R.W.N.RET.BAD:
xor al,al
jmp short R.W.N.RET

R.W.N.RET.GOOD:
mov al,1

R.W.N.RET:
add esp,4
pop esi
Ret


; => Rewind NULL-TERMINATED string <=
; IN:
;       ESI = [POINTER] Rewind where
; OUT:
;       ESI = [POINTER] Start of NULL-TERMINATOR-1
REWIND.NT.STRING:

; Searching for NULL TERMINATOR
R.NT.S.LOOP:
cmp [esi],bx
je R.NT.S.RET; Found NT

sub esi,2; Previous word
jmp short R.NT.S.LOOP

R.NT.S.RET:
sub esi,2; Skip NT separator
Ret


; => Search next argument <=
; IN:
;       ESI = [POINTER] Arguments array
;       ECX = [INT] Rest of arguments array
; OUT:
;       ESI = [POINTER] Next possible argument or data
;       ECX = [INT] Corrected counter of ARGS array
;       DX = [CHAR]
;       AL = [BYTE] = 1 if found, zero otherwise
SEARCH.NEXT.ARGUMENT:

xor dx,dx

; Searching
S.N.A.LOOP:
Call SEARCH.WORD
test al,al
je S.N.A.RET.BAD; No more arguments

; Check if this is an actual argument
add esi,2; Skip first zero separator
dec ecx
cmp [esi],bx
je S.N.A.LOOP; Can't be zero - not an argument. Check next
add esi,2; Skip potential argument symbol
dec ecx
cmp [esi],bx
jne S.N.A.LOOP; Must be zero - not an argument. Check next

; Found, set up DX and correct rest of the counter
mov dx,[esi-2]; DX = UTF-16 character
test ecx,ecx; Protect from overflow
je S.N.A.RET.GOOD
add esi,2; Skip afterwards zero separator
dec ecx

S.N.A.RET.GOOD:
mov al,1
jmp short S.N.A.RET

S.N.A.RET.BAD:
xor al,al

S.N.A.RET:
Ret


; => Search for a word in NULL-TERMINATED string <=
; IN:
;       DX = [CHAR] Search what
;       ESI = [POINTER] Search where
; OUT:
;       AL = [BYTE] 0 - Fail, 1 - Success
;       ECX = [INT] Words from start to a place we found target
;       ESI = [POINTER] Place we found the char
SEARCH.WORD.NT:
SEARCH.CHAR.NT:; alias

xor ecx,ecx

; Searching
S.W.N.LOOP:

cmp [esi],dx; Compare word with source
je S.W.N.RET.GOOD; Found
cmp [esi],bx; See if we reached NULL-TERMINATOR
je S.W.N.RET.BAD; Not found

add esi,2; Next word
inc ecx; +1 to counter
jmp short S.W.N.LOOP

; Didn't find
S.W.N.RET.BAD:
xor al,al
jmp short S.W.N.RET

; Yes
S.W.N.RET.GOOD:
mov al,1

S.W.N.RET:
Ret


; => Skip characters backward (source) <=
; IN:
;       ESI = [POINTER] Where to skip chars
;       ECX = [INT] Chars to skip
; OUT:
;       ESI = [POINTER] Next char
SKIP.CHARACTERS.UTF16.BACKWARDS:
SKIP.CHARACTERS.BACKWARDS:; Alias

sub esi,ecx
sub esi,ecx

Ret


; => Skip characters backward (destination) <=
; IN:
;       EDI = [POINTER] Where to skip chars
;       ECX = [INT] Chars to skip
; OUT:
;       EDI = [POINTER] Next char
SKIP.CHARACTERS.UTF16.BACKWARDS.DST:
SKIP.CHARACTERS.BACKWARDS.DST:; Alias

sub edi,ecx
sub edi,ecx

Ret


; => Skip NULL-TERMINATED string <=
; IN:
;       ESI = [POINTER] Skip where
; OUT:
;       ESI = [POINTER] Position after NULL-TERMINATOR
SKIP.NT.STRING:

; Searching for NULL TERMINATOR
SK.NT.S.LOOP:
cmp [esi],bx
je SK.NT.S.RET; Found NT

add esi,2; Next char
jmp short SK.NT.S.LOOP

SK.NT.S.RET:
add esi,2; Position after NT
Ret


; => Skip NULL-TERMINATED array <=
; IN:
;       ESI = [POINTER] Skip where
; OUT:
;       ESI = [POINTER] Position after NULL-TERMINATOR
SKIP.NT.SEPARATED.ARRAY:

; Searching
S.NT.S.A.LOOP:
cmp [esi],ebx
je S.NT.S.A.RET; Found two zero words

add esi,2; Next word
jmp short S.NT.S.A.LOOP

S.NT.S.A.RET:
add esi,2; Position after end of array
Ret


; => Split string <=
; Splits string replacing matching char in DX by zero,
; so we have a NULL-TERMINATED set of strings.
; IN:
;       ESI = [POINTER] String to split
;       DX = [CHAR] Character to search for
SPLIT.STRING:

push esi; Save start of string

; Searching
S.S.LOOP:
Call SEARCH.CHAR.NT
test al,al
je S.S.RET; Done

; Found, replacing
mov [esi],bx; Remove it
add esi,2; Next word
jmp short S.S.LOOP

S.S.RET:
pop esi; Restore start of string
Ret