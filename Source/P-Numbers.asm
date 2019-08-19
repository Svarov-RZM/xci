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
;       EDX = [INT] RHS: Optional for '()'
; OUT:
;       EAX = [INT] Result
CALCULATE.SIMPLE:

; Determine action
cmp al,'='
je C.S.ASS; He-he, ass... It's from Assignment
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

; Check for negative sign
cmp eax,0x7FFFFFFF; Positive or negative?
jnae C.B.T.S.POS; Positive
xor dh,dh
mov dl,"-"
mov [esi],dx
Call SKIP.CHAR.FORWARD

; Set up temp space
C.B.T.S.POS:
push esi; Start of resulting string
mov ecx,17; Place to hold a 32bit integer
Call SKIP.CHARACTERS
Call ADD.NULL.TERMINATOR
Call REWIND.CHAR

; Convert one grade number
cmp eax,9
jg C.B.T.S.PREPARE
add al,30h; 30h - 0 in ACSII
mov [esi],ax; UTF-16 char
jmp C.B.T.S.REP

C.B.T.S.PREPARE:
Call DISABLE.DIVISION.ROUNDING
mov edx,10; Optimization. We'll constantly compare against it

; Convert the number
C.B.T.S.LOOP:
mov ecx,10; Divider
Call DIVIDE.INTEGER.FPU

; Add char to destination
add cl,30h; 30h - 0 in ACSII
xor ch,ch; To make it UTF-16
mov [esi],cx; UTF-16 char
Call REWIND.CHAR; Next position
cmp eax,edx; Number > 10?
jae C.B.T.S.LOOP; Still got some work to do

; Finalizing
C.B.T.S.FIN:
test al,al; Not zero?
je C.B.T.S.REP; Zero, no need for correction
add al,30h; 30h - 0 in ACSII
xor ah,ah; To make it UTF-16
mov [esi],ax; UTF-16 char

; Replace string
C.B.T.S.REP:
pop edi
Call COPY.NT.STR

C.B.T.S.RET:
Ret


; => Convert decimal number to binary <=
; IN:
;       ESI = [POINTER] Decimal string
; OUT:
;       EAX = [INT] Binary representation
CONVERT.DECIMAL.STRING.TO.INTEGER:

push ebx; Will be result

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

Ret


; => Convert hexadecimal number to binary <=
; IN:
;       ESI = [POINTER] Hex string
; OUT:
;       EAX = [INT] Binary representation
CONVERT.HEXADECIMAL.STRING.TO.INTEGER:

push ebx; Result will be here

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


; => Divide integer using FPU <=
; IN:
;       EAX = [INT] Divident
;       ECX = [INT] Divider
; OUT:
;       EAX = [INT] Result
;       ECX = [INT] Remainder
DIVIDE.INTEGER.FPU:
DIVIDE.INTEGER:; Alias

sub esp,12; We need 3 DWORDs for work
mov [esp],eax; Divident
mov [esp+4],ecx; Divider
; [esp+8] will be remainder

; Prepare
fild dword [esp+4]; Divider
fild dword [esp]; Divident
cmp dword [esp],0x7FFFFFFF; Can't do more than 0x7FFFFFFF values
jnae D.I.F.POS; Value is positive
fchs; Invert the sign

; Divide
D.I.F.POS:
fprem; Get remainder from division (ST0)
fist dword [esp+8]; Store result (REMAINDER)
fincstp; Stack correction. ST0 was remainder, but now divider
fidivr dword [esp]; Divide number by Divident
fist dword [esp]; New number
ffree st0; Free registers
ffree st7; Free registers

; Finalizing
mov eax,[esp]; Result
mov ecx,[esp+8]; Remainder

; Clear stack
add esp,12
Ret


; => Disable rounding when dividing using FPU <=
DISABLE.DIVISION.ROUNDING:

sub esp,4; FPU: Control word

fstcw word [esp]; Get Control word
mov dx,[esp]
or dx,0C00h; Set truncate bits (will NOT round!)
mov [esp],dx
fldcw word [esp]; Set Control word

add esp,4

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
mul ecx

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