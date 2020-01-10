; P-Numbers.asm
;
; Copyright (c) 2019, Dmitry Razumovsky (Svarov-RZM)
; You may distribute under the terms of BSD 2-Clause License
; as specified in the LICENSE.TXT file.
;
; >>>=== NUMBERS-SPECIFIC PROCEDURES ===<<<
; => Do simple calculations <=
; IN:
;       AX = [CHAR] Indicates mode:
;               '=' = Perform assignment
;               '+' = Perform addition
;               '-' = Perform subtraction
;               '(' = Perform decrement
;               ')' = Perform increment
;       ECX = [INT] LHS
;       EDX = [INT] RHS: Not used for '()'
; OUT:
;       EAX = [INT] Result
CALCULATE.SIMPLE:

; Determine action
cmp al,'='
je C.S.ASS; He-he, ass... it's from assignment
cmp al,'+'
je C.S.ADD
cmp al,'-'
je C.S.SUB
cmp al,'('
je C.S.DEC
cmp al,')'
je C.S.INC
jmp short C.S.RET; Unknown action

; Assignment
C.S.ASS:
mov ecx,edx
jmp short C.S.RET

; Addition
C.S.ADD:
add ecx,edx
jmp short C.S.RET

; Subtraction
C.S.SUB:
sub ecx,edx
jmp short C.S.RET

; Decrement
C.S.DEC:
dec ecx
jmp short C.S.RET

; Increment
C.S.INC:
inc ecx

C.S.RET:
xchg eax,ecx; EAX = Result
Ret


; => Convert binary number to string as DEC <=
; TO FIX: This procedure can't handle negative numbers
; IN:
;       EAX = [INT] Convert what
;       ESI = [POINTER] Where to save converted number
CONVERT.BIN.TO.STR:

; Start of resulting string
push esi

; Indicate a sign
; By default it's a positive number (0)
; if change to -1 - we'll add '-' as prefix
push ebx

; Check for negative sign and invert it if so
; It's just easier to work with positive numbers
cmp eax,MAX_POSITIVE_INT
jnae C.B.T.S.POS
neg eax
mov [esp],eax

; Set up temp space
C.B.T.S.POS:
mov ecx,32; Place to hold a 32/64bit integer
Call SKIP.CHARACTERS
Call ADD.NULL.TERMINATOR

; Convert the number
; We continuously divide EAX by decimal base (10) and write down
; the remainder until there's nothing left (EAX = 0)
C.B.T.S.LOOP:
mov ecx,10; Divider
Call DIVIDE.INTEGER

; To next position
Call REWIND.CHAR

; Add char to destination and set next position
; 30h = '0' in ACSII
add cx,30h
mov [esi],cx

; Continue until we have nothing to divide
test eax,eax
jne C.B.T.S.LOOP

; Check if we need to add sign
pop eax
test eax,eax
je C.B.T.S.COPY; Nope

; Add negative sign
Call REWIND.CHAR
mov ax,'-'
mov [esi],ax

; Restore pointer where we should place result
; and transfer string to requested position
C.B.T.S.COPY:
pop edi
Call COPY.NT.STR

Ret


; => Convert decimal number to binary <=
; IN:
;       ESI = [POINTER] Decimal string
; OUT:
;       EAX = [INT] Binary representation
CONVERT.DECIMAL.STRING.TO.INTEGER:

; Place for sign flag and result
push ebx; Sign
push ebx; Result

; Check for positive/negative number
Call GET.DIRECTION.OF.DEC.NUMBER
test ecx,ecx
je C.D.S.T.I.FIN
mov [esp+4],ecx

; Convert to binary
C.D.S.T.I.LOOP:

; Validate character
xor eax,eax
Call ACQUIRE.CHAR

cmp ax,'0'
jb C.D.S.T.I.FIN
cmp ax,'9'
ja C.D.S.T.I.FIN
push eax; Save char

; Multiply previous result by 10
mov eax,10
mov ecx,[esp+4]; Previous result
Call MULTIPLY.INTEGER
mov [esp+4],eax; Previous result

; Convert ASCII number to binary
pop eax
sub eax,'0'
add [esp],eax; Add current digit

jmp short C.D.S.T.I.LOOP

; Finalize
C.D.S.T.I.FIN:

pop eax; Result
pop ecx; Sign

; Invert sign if negative number
cmp ecx,-1
jne C.D.S.T.I.RET

neg eax

C.D.S.T.I.RET:

Ret


; => Convert hexadecimal number to binary <=
; IN:
;       ESI = [POINTER] Hex string
; OUT:
;       EAX = [INT] Binary representation
CONVERT.HEXADECIMAL.STRING.TO.INTEGER:

; Place for sign flag and result
push ebx; Sign
push ebx; Result

; Check for positive/negative number
Call GET.DIRECTION.OF.HEX.NUMBER
test ecx,ecx
je C.H.S.T.I.FIN
mov [esp+4],ecx

C.H.S.T.I.LOOP:

; Validate character
xor eax,eax
Call ACQUIRE.CHAR

cmp ax,'a'
jb C.H.S.T.I.HEXA; Lower: Maybe user typed 'A' instead of 'a'?
cmp ax,'f'
ja C.H.S.T.I.FIN; Greater: Not a number - abort here
sub ax,'a'
add ax,10
jmp short C.H.S.T.I.SAVE

C.H.S.T.I.HEXA:
cmp al,'A'
jb C.H.S.T.I.DEC; Lower: Maybe it's a decimal value?
cmp al,'F'
ja C.H.S.T.I.FIN; Greater: Not a number - abort here
sub ax,'A'
add ax,10
jmp short C.H.S.T.I.SAVE

C.H.S.T.I.DEC:
cmp ax,'0'
jb C.H.S.T.I.FIN
cmp ax,'9'
ja C.H.S.T.I.FIN
sub ax,'0'

; Save char
C.H.S.T.I.SAVE:
push eax

; Multiply previous result by 10
mov eax,16
mov ecx,[esp+4]; Previous result
Call MULTIPLY.INTEGER
mov [esp+4],eax; Previous result

; Convert ASCII number to binary
pop eax
add [esp],eax; Add current digit

jmp short C.H.S.T.I.LOOP

; Finalize
C.H.S.T.I.FIN:

pop eax; Result
pop ecx; Sign

; Invert sign if negative number
cmp ecx,-1
jne C.H.S.T.I.RET

neg eax

C.H.S.T.I.RET:

Ret


; => Convert array of numbers to binary representation (WORD array) <=
; IN:
;       ESI = [POINTER] Numbers array (hex)
;       EDI = [POINTER] Save where [PRESERVED]
; OUT:
;       ECX = [INT] How many numbers were copied
CONVERT.STR.ARRAY.TO.WORD:

push edi
sub esp,4; Local var: Array counter
mov [esp],ebx; Null array counter

; Loop over all numbers
C.S.A.T.W.LOOP:
cmp [esi],bx
je C.S.A.T.W.END; No more numbers

; Convert to binary
Call CONVERT.HEXADECIMAL.STRING.TO.INTEGER

; Save result
mov [edi],ax
add edi,2; Next number
inc dword [esp]; Array counter
jmp short C.S.A.T.W.LOOP

; Finalizing
C.S.A.T.W.END:
pop ecx; Array counter (WORD)
pop edi; Start of numbers

Ret


; => Divide integer using CPU <=
; IN:
;       EAX = [INT] Divident
;       ECX = [INT] Divider
; OUT:
;       EAX = [INT] Result
;       ECX = [INT] Remainder
DIVIDE.INTEGER.CPU:
DIVIDE.INTEGER:; Alias

; Check for division by zero
; We don't want to destroy the Universe... yet.
test ecx,ecx
je EXIT

; Convert EAX to EDX:EAX
cdq

; Divide and place remainder in ECX
idiv ecx
xchg ecx,edx

Ret


; => Get direction of decimal number <=
; IN:
;       ESI = [POINTER] Number
; OUT:
;       ESI = [POINTER] Number, '-' will be skipped if negative
;       ECX = [INT] -1 if negative, 1 if positive, 0 if not a number
GET.DIRECTION.OF.DEC.NUMBER:

; Temp result, will be OUT in the end
; Positive by default
mov ecx,1

; See if negative
Call GET.CHAR
cmp ax,'-'
jne G.D.O.D.N.NUM
Call SKIP.CHAR.FORWARD
neg ecx

; See if it's number at all
Call GET.CHAR
G.D.O.D.N.NUM:
cmp ax,'0'
jb G.D.O.D.N.BAD
cmp ax,'9'
ja G.D.O.D.N.BAD

Ret

; Not a number
G.D.O.D.N.BAD:

xor ecx,ecx

Ret


; => Get direction of hexadecimal number <=
; IN:
;       ESI = [POINTER] Number
; OUT:
;       ESI = [POINTER] Number, '-' will be skipped if negative
;       ECX = [INT] -1 if negative, 1 if positive, 0 if not a number
GET.DIRECTION.OF.HEX.NUMBER:

; Temp result, will be OUT in the end
; Positive by default
mov ecx,1

; See if negative
Call GET.CHAR
cmp ax,'-'
jne G.D.O.H.N.NUM
Call SKIP.CHAR.FORWARD
neg ecx

; See if it's number at all
Call GET.CHAR
G.D.O.H.N.NUM:
cmp ax,'a'
jb G.D.O.H.N.HEXA; Lower: Maybe user typed 'A' instead of 'a'?
cmp ax,'f'
ja G.D.O.H.N.BAD; Greater: Not a number - abort here
jmp short G.D.O.H.N.OK

G.D.O.H.N.HEXA:
cmp al,'A'
jb G.D.O.H.N.DEC; Lower: Maybe it's a decimal value?
cmp al,'F'
ja G.D.O.H.N.BAD; Greater: Not a number - abort here
jmp short G.D.O.H.N.OK

G.D.O.H.N.DEC:
cmp ax,'0'
jb G.D.O.H.N.BAD
cmp ax,'9'
ja G.D.O.H.N.BAD

G.D.O.H.N.OK:

Ret

; Not a number
G.D.O.H.N.BAD:

xor ecx,ecx

Ret


; => Multiply (using CPU) <=
; IN:
;       ECX = [INT] Multiplicand
;       EAX = [INT] Multiplier
; OUT:
;       EAX = [INT] Result
; NOTE: We omit EDX part so result can't be greater than 32bit
MULTIPLY.INTEGER.CPU.OPTIMIZED:
MULTIPLY.INTEGER:; Alias

xchg ecx,eax
imul ecx

Ret


; => Process numerical comparison <=
; IN:
;       EAX = [DWORD] Type: eq/ne/gt/etc
;       ECX = [INT] LHS
;       EDX = [INT] RHS
; OUT:
;       AL = [BYTE] TRUE/FALSE
PROCESS.NUMERICAL.COMPARISON:

; Check type
cmp eax,PREFIX_EQU
je P.N.C.EQU
cmp eax,PREFIX_NEQ
je P.N.C.NEQ
cmp eax,PREFIX_GEQ
je P.N.C.GEQ
cmp eax,PREFIX_LEQ
je P.N.C.LEQ
cmp eax,PREFIX_GTR
je P.N.C.GTR
cmp eax,PREFIX_LSS
je P.N.C.LSS

; Check if equals
P.N.C.EQU:
cmp ecx,edx
je P.N.C.RET.GOOD
jmp short P.N.C.RET.BAD

; Check if not equals
P.N.C.NEQ:
cmp ecx,edx
jne P.N.C.RET.GOOD
jmp short P.N.C.RET.BAD

; Check if greater or equals
P.N.C.GEQ:
cmp ecx,edx
jge P.N.C.RET.GOOD
jmp short P.N.C.RET.BAD

; Check if less or equals
P.N.C.LEQ:
cmp ecx,edx
jle P.N.C.RET.GOOD
jmp short P.N.C.RET.BAD

; Check if greater
P.N.C.GTR:
cmp ecx,edx
jg P.N.C.RET.GOOD
jmp short P.N.C.RET.BAD

; Check if less
P.N.C.LSS:
cmp ecx,edx
jl P.N.C.RET.GOOD
jmp short P.N.C.RET.BAD

P.N.C.RET.GOOD:
mov al,1
jmp short P.N.C.RET

P.N.C.RET.BAD:
xor al,al

P.N.C.RET:
Ret