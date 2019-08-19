; P-Loops.asm
;
; Copyright (c) 2019, Dmitry Razumovsky (Svarov-RZM)
; You may distribute under the terms of BSD 2-Clause License
; as specified in the LICENSE.TXT file.
;
; >>>=== LOOP PROCEDURES ===<<<
; => Loop over bytes <=
; IN:
;       EAX = [POINTER] Callback
;       ESI = [POINTER] Bytes array
;       ECX = [INT] Counter
; OUT:
;       ESI = [POINTER] End of bytes
LOOP.OVER.BYTES:
sub esp,8
mov [esp],eax; Save callback
mov [esp+4],ecx; Save counter

; Loop until counter > 0
L.O.B.LOOP:
test [esp+4],ebx
je L.O.B.RET
Call ACQUIRE.BYTE
dec dword [esp+4]

; Call specified callback while return code != 0
; AL contains byte
Call [esp]
test al,al
jne L.O.B.LOOP

L.O.B.RET:
add esp,8
Ret


; => Loop over matched WORDs <=
; IN:
;       DX = [WORD] What to search
;       EAX = [POINTER] Callback
;       ECX = [INT] Array size
;       ESI = [POINTER] WORDs array
; SEQ:
;       ESI = [POINTER] Next position
; OUT:
;       ESI = [POINTER] End of WORDs
LOOP.OVER.MATCHED.WORDS:
LOOP.OVER.MATCHED.CHARS:; Alias
sub esp,8
mov [esp],eax; Save callback
mov [esp+4],ecx; Save counter

; Loop until word is found (AL != 0)
L.O.M.W.LOOP:
mov ecx,[esp+4]
Call SEARCH.WORD
test al,al
je L.O.M.W.RET
; Update counter after successful SEARCH.WORD call
mov [esp+4],ecx

; Call specified callback
Call [esp]
test al,al
jne L.O.M.W.LOOP; Loop while return code != 0

L.O.M.W.RET:
add esp,8
Ret


; => Loop over characters in NT string <=
; IN:
;       EAX = [POINTER] Callback
;       ESI = [POINTER] NT string
; SEQ:
;       ESI = [POINTER] Next position
;       AX = [CHAR]
; OUT:
;       ESI = [POINTER] End of symbols
LOOP.OVER.CHARS.NT:
sub esp,4
mov [esp],eax; Save callback

; We loop until NULL-TERMINATOR
L.O.C.N.LOOP:
Call ACQUIRE.CHAR
test ax,ax
je L.O.C.N.RET

; Call specified callback
; AX contains UTF-16 symbol
Call [esp]
test al,al
jne L.O.C.N.LOOP; Loop while return code != 0

L.O.C.N.RET:
add esp,4
Ret


; => Loop over NT separated strings <=
; IN:
;       EAX = [POINTER] Callback
;       ESI = [POINTER] Array of NT strings
; SEQ:
;       ESI = [POINTER] Next string
; OUT:
;       ESI = [POINTER] End of array
LOOP.OVER.STRINGS:
sub esp,4
mov [esp],eax; Save callback

; We loop until there's no more strings
L.O.S.LOOP:
Call GET.CHAR
test ax,ax
je L.O.S.RET

; Call specified callback
Call [esp]
test al,al
jne L.O.S.LOOP; Loop while return code != 0

L.O.S.RET:
add esp,4
Ret


; => Loop over WORDs <=
; IN:
;       EAX = [POINTER] Callback
;       ECX = [INT] Array size
;       ESI = [POINTER] WORDs
; SEQ:
;       ESI = [POINTER] Current position
;       AX = [WORD]
; OUT:
;       ESI = [POINTER] End of WORDs
LOOP.OVER.WORDS:
LOOP.OVER.CHARS:; Alias

; Init local stack and save callback
sub esp,4
mov [esp],eax

; We loop until ECX > 0
L.O.C.LOOP:
test ecx,ecx
je L.O.C.RET

; Get word
mov ax,[esi]

; Call specified callback
; Break if callback returned zero
Call [esp]
test al,al
je L.O.C.RET

; Set next position and correct counter
Call SKIP.WORD.FORWARD
dec ecx
jmp short L.O.C.LOOP

; Clear stack and return
L.O.C.RET:
add esp,4
Ret


; => Loop specified amount of times <=
; IN:
;       EAX = [POINTER] Callback
;       ECX = [INT] Number of times to call back
LOOP.TIMES:
sub esp,8
mov [esp],eax; Save callback
mov [esp+4],ecx; Save counter

L.T.LOOP:
cmp [esp+4],ebx; Counter reached zero - return
je L.T.RET

; Call specified callback
Call [esp]
dec dword [esp+4]; Called one time
test al,al
jne L.T.LOOP; Loop while return code != 0

L.T.RET:
add esp,8; Remove local vars
Ret
