; P-Specific.asm
;
; Copyright (c) 2019, Dmitry Razumovsky (Svarov-RZM)
; You may distribute under the terms of BSD 2-Clause License
; as specified in the LICENSE.TXT file.
;
; >>>=== PROGRAM SPECIFIC PROCEDURES ===<<<
; => Cancel execution if last comparison was FLASE <=
; OUT:
;       AL = [BYTE] 0 - Cancel, 1 - Process
CANCEL.IF.FALSE:

cmp [ebp-66],ebx; Errorlevel
je C.IF.F.RET.GOOD

C.IF.F.RET.BAD:
xor al,al
jmp short C.IF.F.RET

C.IF.F.RET.GOOD:
mov al,1
C.IF.F.RET:
Ret


; => Count string based on several 'T' arguments <=
; IN:
;       ECX = [INT] Current 'T' counter (string)
;       EDX = [INT] How many 'T' arguments to count
; OUT:
;       ECX = [INT] Resulting string counter
COUNT.STRING.T:

push esi; Preserve pointer to current string
push edx
push ecx

; Prepare initial variables
mov esi,[ebp-20]; Pointer: Arguments array
mov ecx,[ebp-28]; Counter: Rest of arguments array

; Find next 'T' argument
C.S.T.LOOP:

; Return if we processed all requested arguments
cmp [esp+4],ebx
je C.S.T.RET

; Try to find the next 'T' argument
; We exit if we couldn't find it (user screwed up the counter)
xor ax,ax
mov al,'T'
Call FIND.ARGUMENT
test al,al
je EXIT

; Count string and add to the current counter
; ECX currently holds 'Rest of arguments array' so we must save it
push ecx
Call COUNT.STRING
add [esp+4],ecx
pop ecx
dec dword [esp+4]; One argument processed
jmp short C.S.T.LOOP

C.S.T.RET:
pop ecx
add esp,4
pop esi
Ret


; => Dispatch draw command to all active elements <=
DRAW.ACTIVE.ELEMENTS:

; Save current argument position on stack
push dword [ebp-20]; Point of return after procedure call
push dword [ebp-28]; Counter of arguments array [current]

; Set up event for active elements, D = Draw
xor eax,eax
mov ax,'D'
mov [MBI.E.EVENT],eax

; Set up callback and call it
mov eax,D.A.E.CALLBACK
mov edi,[ebp-36]
mov cx,'F'
Call LOOP.OVER.ACTIVE.ELEMENTS

; Active elements processed
; Restore argument position and return
D.A.E.END:
pop eax
mov [ebp-28],eax; Correct counter of arguments array [dynamic]
pop eax
mov [ebp-20],eax; Current position in arguments array

mov al,1

Ret

; CALLBACK: For each active element
D.A.E.CALLBACK:

; Set DBOX to new pointer
mov [ebp-82],esi

; Call label
; P.AT.CALL will return to us after procedure is done
; Warning: Calling other procedures inside is not supported!
mov [ebp-266],al
add esi,8; DBOX structure is 8 bytes
Call P.AT.CALL

Ret


; => Determine if active element is relative to left <=
; IN:
;       EDI = [POINTER] DBOX RHS
;       ESI = [POINTER] DBOX LHS
; OUT:
;       AL = [BYTE] 1 - Relative, 0 - Not
IS.ELEMENT.RELATIVE.TO.LEFT:

; Check if active element is on the same row to the left
; X left/right should be lower, Y top/bottom shouldn't be greater/lower
I.E.R.T.L.X:
mov ax,[edi]; X left
cmp [esi],ax
jae I.E.R.T.L.NO
mov ax,[edi+2]; X right
cmp [esi+2],ax
jae I.E.R.T.L.NO
I.E.R.T.L.Y:
mov ax,[edi+4]; Y top
cmp [esi+4],ax
jb I.E.R.T.L.NO
mov ax,[edi+6]; Y bottom
cmp [esi+6],ax
ja I.E.R.T.L.NO

; Element is relative
mov al,1
Ret

; Element is NOT relative
I.E.R.T.L.NO:
xor al,al
Ret


; => Determine if active element is relative to right <=
; IN:
;       EDI = [POINTER] DBOX RHS
;       ESI = [POINTER] DBOX LHS
; OUT:
;       AL = [BYTE] 1 - Relative, 0 - Not
IS.ELEMENT.RELATIVE.TO.RIGHT:

; Check if active element is on the same row to the right
; X left/right should be greater, Y top/bottom shouldn't be greater/lower
I.E.R.T.R.X:
mov ax,[edi]; X left
cmp [esi],ax
jbe I.E.R.T.R.NO
mov ax,[edi+2]; X right
cmp [esi+2],ax
jbe I.E.R.T.R.NO
I.E.R.T.R.Y:
mov ax,[edi+4]; Y top
cmp [esi+4],ax
jb I.E.R.T.R.NO
mov ax,[edi+6]; Y bottom
cmp [esi+6],ax
ja I.E.R.T.R.NO

; Element is relative
mov al,1
Ret

; Element is NOT relative
I.E.R.T.R.NO:
xor al,al
Ret


; => Determine if active element is relative to up <=
; IN:
;       EDI = [POINTER] DBOX RHS
;       ESI = [POINTER] DBOX LHS
; OUT:
;       AL = [BYTE] 1 - Relative, 0 - Not
IS.ELEMENT.RELATIVE.TO.UP:

; Check if active element is on the same column to the up
; X left/right should be equal, Y top/bottom should be lesser (because 0 is the top most)
I.E.R.T.U.X:
mov ax,[edi]; X left
cmp [esi],ax
jne I.E.R.T.U.NO
mov ax,[edi+2]; X right
cmp [esi+2],ax
jne I.E.R.T.U.NO
I.E.R.T.U.Y:
mov ax,[edi+4]; Y top
cmp [esi+4],ax
jae I.E.R.T.U.NO
mov ax,[edi+6]; Y bottom
cmp [esi+6],ax
jae I.E.R.T.U.NO

; Element is relative
mov al,1
Ret

; Element is NOT relative
I.E.R.T.U.NO:
xor al,al
Ret


; => Determine if active element is relative to down <=
; IN:
;       EDI = [POINTER] DBOX RHS
;       ESI = [POINTER] DBOX LHS
; OUT:
;       AL = [BYTE] 1 - Relative, 0 - Not
IS.ELEMENT.RELATIVE.TO.DOWN:

; Check if active element is on the same column to the down
; X left/right should be equal, Y top/bottom should be greater (because 0 is the top most)
I.E.R.T.D.X:
mov ax,[edi]; X left
cmp [esi],ax
jne I.E.R.T.D.NO
mov ax,[edi+2]; X right
cmp [esi+2],ax
jne I.E.R.T.D.NO
I.E.R.T.D.Y:
mov ax,[edi+4]; Y top
cmp [esi+4],ax
jbe I.E.R.T.D.NO
mov ax,[edi+6]; Y bottom
cmp [esi+6],ax
jbe I.E.R.T.D.NO

; Element is relative
mov al,1
Ret

; Element is NOT relative
I.E.R.T.D.NO:
xor al,al
Ret


; => Loop over active elements <=
; IN:
;       EAX = [POINTER] Callback
;       EDX = [BASIC_REGISTER] Custom: Argument to callback
;       EDI = [POINTER] Starting variable in VARS structure
;       CX = [CHAR] Direction: 'F' = Forward, 'B' = Backward
; STEP:
;       ESI = [POINTER] Data section of variable
;       EDX = [BASIC_REGISTER] Custom argument
LOOP.OVER.ACTIVE.ELEMENTS:

; Save direction and callback
push ecx; Will become a pointer to GET.*.VARIABLE
push eax

; Set up what we're calling depending on direction
cmp cx,'F'
je L.O.A.E.FORWARD
cmp cx,'B'
je L.O.A.E.BACKWARD
jmp EXIT

; Moving forward
L.O.A.E.FORWARD:
mov dword [esp+4],GET.NEXT.VARIABLE
jmp short L.O.A.E.LOOP

; Moving backward
L.O.A.E.BACKWARD:
mov dword [esp+4],GET.PREVIOUS.VARIABLE

; Get next variable
L.O.A.E.LOOP:
push edx
Call [esp+8]
pop edx
test esi,esi
je L.O.A.E.END; Reached the end of VARS buffer

; Check type, we only need active elements
cmp ax,'E'
jne L.O.A.E.LOOP

; Save current pointer to next variable
push edi

; Enter callback
Call [esp+4]

; Restore pointer to next variable
pop edi

; Abort on unsuccessful callback or continue search
test al,al
jne L.O.A.E.LOOP

; No more active elements
L.O.A.E.END:
add esp,8; Clear stack

Ret


; => Obtain active element relative to another <=
; IN:
;       AX = [CHAR] Relative position: 'L' = Left, R = 'Right', 'U' = Up, 'D' = Down
;       DX = [CHAR] Direction to move: 'F' = Forward, 'B' = Backward
; OUT:
;       AL = [BYTE] Flag: 0 - No element found, 1 - Found
;       ESI = [POINTER] DATA section of selected element if AL = 1
;       EDX = [POINTER] DATA section of previously selected element if AL = 1
OBTAIN.ACTIVE.ELEMENT.RELATIVE:

; We must set starting position in VARS to current element
mov esi,[MBI.E.SELECTED]; Points to DATA section
sub esi,12; Points to the last char of NAME section
Call REWIND.NT.STRING
mov ecx,2
Call SKIP.CHARACTERS; Points to NAME section
mov edi,esi

; Set up callback and call it
mov cx,dx
mov edx,eax
mov eax,O.A.E.R.CALLBACK
Call LOOP.OVER.ACTIVE.ELEMENTS

; O.A.E.L.CALLBACK will return TRUE as FALSE, we have to correct that
test al,al
je O.A.E.R.GOOD
xor al,al
Ret

; Element was found
O.A.E.R.GOOD:
mov al,1
Ret

; CALLBACK: Try to find the next element to the left of the currently selected one
O.A.E.R.CALLBACK:

; EDI = Pointer: DBOX of the currently selected element
; ESI = Pointer: DBOX of the next element
mov edi,[MBI.E.SELECTED]

; Check if current active element is relative to another depending on what was passed in EDX
cmp dx,'L'
je O.A.E.R.LEFT
cmp dx,'R'
je O.A.E.R.RIGHT
cmp dx,'U'
je O.A.E.R.UP
cmp dx,'D'
je O.A.E.R.DOWN
jmp short O.A.E.R.NO; Unknown argument

; Call the appropriate procedure
O.A.E.R.LEFT:
Call IS.ELEMENT.RELATIVE.TO.LEFT
jmp short O.A.E.R.CMP
O.A.E.R.RIGHT:
Call IS.ELEMENT.RELATIVE.TO.RIGHT
jmp short O.A.E.R.CMP
O.A.E.R.UP:
Call IS.ELEMENT.RELATIVE.TO.UP
jmp short O.A.E.R.CMP
O.A.E.R.DOWN:
Call IS.ELEMENT.RELATIVE.TO.DOWN

; Let's compare result
O.A.E.R.CMP:
test al,al
jne O.A.E.R.YES

; Don't match, continue search
O.A.E.R.NO:
mov al,1
Ret

; Match. Save new pointer and abort loop
O.A.E.R.YES:
mov edx,[MBI.E.SELECTED]
mov [MBI.E.PREVIOUS],edx
mov [MBI.E.SELECTED],esi
xor al,al
Ret


; => Obtain active element by absolute coordinates <=
; IN:
;       EAX = [DWORD] COORD structure
; OUT:
;       AL = [BYTE] Flag: 0 - No element found, 1 - Found
;       ESI = [POINTER] DATA section of selected element if AL = 1
;       EDX = [POINTER] DATA section of previously selected element if AL = 1
OBTAIN.ACTIVE.ELEMENT.ABSOLUTE:

; Set up callback and call it
mov edx,eax
mov eax,O.A.E.A.CALLBACK
mov edi,[ebp-36]
mov cx,'F'
Call LOOP.OVER.ACTIVE.ELEMENTS

; O.A.E.A.CALLBACK will return TRUE as FALSE, we have to correct that
test al,al
je O.A.E.A.GOOD
xor al,al
Ret

; Element was found
O.A.E.A.GOOD:
mov al,1
Ret

; CALLBACK: Try to find the element that overlaps with passed coordinates
O.A.E.A.CALLBACK:

; EDI = Pointer: DBOX of the currently selected element [not used]
; ESI = Pointer: DBOX of the next element
; EDX = COORD
mov edi,[MBI.E.SELECTED]

; Check if COORD match the element
cmp dx,[esi]; X left
jb O.A.E.A.NO
cmp dx,[esi+2]; X right
ja O.A.E.A.NO
O.A.E.A.Y:
mov eax,edx
shr eax,16; Get Y part
cmp ax,[esi+4]; Y top
jb O.A.E.A.NO
cmp ax,[esi+6]
ja O.A.E.A.NO

; Match. Save new pointer and abort loop
O.A.E.A.YES:
mov edx,[MBI.E.SELECTED]
mov [MBI.E.PREVIOUS],edx
mov [MBI.E.SELECTED],esi
xor al,al
Ret

; Don't match, continue search
O.A.E.A.NO:
mov al,1
Ret


; => Wait for flag change <=
; IN:
;       AL = [BYTE] Wait until flag equals this value
;       ESI = [POINTER] Flag location
WAIT.FOR.FLAG.TO.CHANGE:

cmp [esi],al
je W.F.F.T.C.RET

; Delay before the next check (10 ms)
push eax
mov eax,10
Call SLEEP.MS
pop eax
jmp short WAIT.FOR.FLAG.TO.CHANGE

; Got required change, return
W.F.F.T.C.RET:
Ret
