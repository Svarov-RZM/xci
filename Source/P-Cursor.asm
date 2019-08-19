; P-Cursor.asm
;
; Copyright (c) 2019, Dmitry Razumovsky (Svarov-RZM)
; You may distribute under the terms of BSD 2-Clause License
; as specified in the LICENSE.TXT file.
;
; >>>=== CURSOR-SPECIFIC PROCEDURES ===<<<
; => Acquire cursor size and visibility <=
; OUT:
;       In CSV structure
ACQUIRE.CONSOLE.CURSOR:

mov eax,CSV; Cursor Size and Visibility structure
push eax;2
push dword [ebp-118];1; EBP-118 = hndOut
Call [GetConsoleCursorInfo];:2

Ret


; => Acquire cursor position <=
; OUT:
;       EAX = [DWORD] COORD: X Y
;       CX = [WORD] Y
ACQUIRE.CURSOR.POS:

; Check if we are working with current cursor position or internal
cmp [ebp-M_GLOBAL_CURSOR],bl
jne A.C.P.INTERNAL

Call ACQUIRE.CON.SCR.BUF

mov eax,[ebp-12]; Pointer: CSBI
mov cx,[eax+6]; Y
mov eax,[eax+4]; COORD: X Y

Ret

; Working with internal position
A.C.P.INTERNAL:

mov eax,[ebp-44]; AX = X
mov ecx,eax
shr ecx,16; CX = Y

Ret


; => Correct cursor position according to DBOX <=
; OUT:
;       EAX = [DWORD] COORD: Current cursor position
;       ECX = [INT] Data counter for FORMAT.* procedures [PRESERVED]
CORRECT.POS.TO.DBOX:

; Get current position and set up pointers
push ecx
Call ACQUIRE.CURSOR.POS
mov edi,[ebp-82]; Pointer: DBOX
push eax; We may correct it in C.P.T.D.OUTB and in formating

; Check if current cursor position is in DBOX bounds
C.P.T.D.BOUNDSX:
cmp ax,[edi]; X [left] is in bounds?
jb C.P.T.D.OUTBX
cmp ax,[edi+2]; X [right] is in bounds?
ja C.P.T.D.OUTBX
C.P.T.D.BOUNDSY:
cmp cx,[edi+4]; Y [top] is in bounds?
jb C.P.T.D.OUTBY
cmp cx,[edi+6]; Y [bottom] is in bounds?
ja C.P.T.D.OUTBY
jmp short C.P.T.D.FRM; Position is in bounds, check formating

; Current X position is out of bounds
; Set X to DBOX.ROW.LEFT and increase Y because we reached the end of line
C.P.T.D.OUTBX:
mov ax,cx; AX = Y
inc ax; Y+1
mov cx,ax; C.P.T.D.BOUNDSY checks Y in CX
shl eax,16; Y to HIGH part
mov ax,[edi]; X
jmp short C.P.T.D.BOUNDSY

; Current Y position is out of bounds
; Move cursor to the TOP
C.P.T.D.OUTBY:
mov cx,ax; Save X
mov ax,[edi+4]; Y [top]
shl eax,16; Y to HIGH part
mov ax,cx; Restore X

; Format by row/column if set
; ECX is set to counter of Chars/Attributes
C.P.T.D.FRM:
cmp [ebp-M_T_FORMAT_COLUMN],bx
je C.P.T.D.SETP; No formatting
mov ecx,[esp+4]

; Check if need to format based on multiple 'T' arguments
; If so we convert [ebp-M_T_COMPLEX_FORMAT] to a simple 1-digit number and count the specified amount of 'T' arguments
cmp [ebp-M_T_COMPLEX_FORMAT],bl
je C.P.T.D.FRM.DO
push eax; Save current X/Y position
xor edx,edx
mov dl,[ebp-M_T_COMPLEX_FORMAT]
sub dl,'0'
Call COUNT.STRING.T
pop eax

; Set proper cursor position
C.P.T.D.FRM.DO:
Call FORMAT.ROW
Call FORMAT.COLUMN

; It's better to reset formatting on multiple 'T' arguments mode
; If we keep it set, it'd cause more inconvenience for user
cmp [ebp-M_T_COMPLEX_FORMAT],bl
je C.P.T.D.SETP
mov [ebp-M_T_COMPLEX_FORMAT],bl
mov [ebp-M_T_FORMAT_COLUMN],bx

; Set position
C.P.T.D.SETP:
mov [esp],eax; Correct current position
Call SET.CURSOR.POS

C.P.T.D.RET:
pop eax; Position
pop ecx; Counter
Ret


; => Format cursor on ROW <=
; IN:
;       EAX = [DWORD] COORD: X and Y
;       ECX = [INT] Counter: Chars/Attributes
;       EDI = [POINTER] DBOX structure
FORMAT.ROW:

; Check ROW formating
mov al,[ebp-M_T_FORMAT_ROW]
test al,al
je F.R.RET; No row formating
cmp al,'l'; Left
je F.R.LEFT
cmp al,'c'; Center
je F.R.CENTER
cmp al,'r'; Right
je F.R.RIGHT
jmp short F.R.RET; Unknown format

; Format to left
F.R.LEFT:
mov ax,[edi]; AX = X [left]
jmp short F.R.RET

; Format to center
F.R.CENTER:

; Save parameters
push eax; Save COORD
push ecx; Save counter

; Get width - string's length
xor eax,eax
mov ax,[edi+2]; AX = ROW with no shift from left
inc ax; Inclusive: 0..2 = 3 chars
sub ax,[edi]; AX = ROW with shift from left
sub eax,ecx; Width - String's length
js F.R.C.BAD; Got negative number! It means string is greater than row

; Get half of row
mov ecx,2; Divider
Call DIVIDE.INTEGER
add ax,[edi]; Add shift from the left corner if any

; Make a proper COORD structure
mov dx,ax
pop ecx; Restore counter
pop eax; Initial COORD
mov ax,dx; Replace X with corrected value
jmp short F.R.RET

; Revert changes if no room for formatting
F.R.C.BAD:
pop ecx; Restore counter
pop eax; Initial COORD
xor ax,ax; X to ZERO
jmp short F.R.RET

; Format to right
F.R.RIGHT:
mov ax,[edi+2]; AX = ROW size
inc ax; Inclusive: 0..2 = 3 chars
sub ax,cx; AX = ROW size - Char counter
jns F.R.RET
; Got negative number! It means string is greater than a row
xor ax,ax; X to ZERO

F.R.RET:
Ret


; => Format cursor on column <=
; IN:
;       EAX = X and Y
;       ECX = Counter: Chars/Attributes
;       EDI = Pointer: DBOX structure
FORMAT.COLUMN:

; Check COLUMN formating
mov dl,[ebp-M_T_FORMAT_COLUMN]
test dl,dl
je F.C.RET; No column formating
cmp dl,'t'; Top
je F.C.TOP
cmp dl,'c'; Center
je F.C.CENTER
cmp dl,'b'; Bottom
je F.C.BOTTOM
jmp short F.C.RET; Unknown format

; Format to top
F.C.TOP:
mov dx,ax; Save X
mov ax,[edi+4]; AX = Y [top]
shl eax,16; Y to HIGH part
mov ax,dx; X to LOW
jmp short F.C.RET

; Format to center
F.C.CENTER:

; Save parameters
push ecx; Save Counter
push eax; Save COORD

; Get half of column
xor eax,eax
mov ax,[edi+6]; AX = COLUMN with no shift from top
sub ax,[edi+4]; AX = COLUMN with shift from top
inc ax; In DBOX, we draw inclusively, so Y=0,3 equals 4 columns
mov ecx,2; Divider
Call DIVIDE.INTEGER
sub eax,ecx;  Correct remainder
add ax,[edi+4]; Add shift from the top corner if any

; Make a proper COORD structure
mov dx,ax; DX = Corrected Y
pop eax; Initial COORD
mov cx,ax; CX = X
mov ax,dx; AX = Y [low]
shl eax,16; Y [high]
mov ax,cx; Place X
pop ecx; Restore counter
jmp short F.C.RET

; Format to bottom
F.C.BOTTOM:

mov dx,ax; Save X
mov ax,[edi+6]; AX = Y [bottom]
shl eax,16; Y to HIGH part
mov ax,dx; X to LOW

F.C.RET:
Ret


; => Prepare X <=
; Converts user defined structure to a proper cursor position.
; Structure is [=][+][-]X, e.g. '=0' or '+6'
; IN:
;       ESI = [POINTER] User defined structure
; OUT:
;       EAX = [DWORD] COORD structure
PREPARE.X:

push edi; Preserve EDI

Call ACQUIRE.CON.SCR.BUF; EDI = Current screen buffer info

; Acquire control char and save it for CALCULATE.SIMPLE
Call ACQUIRE.CHAR
push eax

; Convert to proper binary form and call CALCULATE.SIMPLE
Call CONVERT.DECIMAL.STRING.TO.INTEGER
xor ecx,ecx
mov cx,[edi+4]; ECX = LHS: current X for CSBI structure
mov edx,eax; EDX = RHS: specified by user
pop eax; EAX = Mode for CALCULATE.SIMPLE
Call CALCULATE.SIMPLE
mov cx,[edi+6]
; AX = New X value
; CX = Old Y value
; [EDI] = Max X value
; [EDI+2] = Max Y value

; Wrap if X/Y is out of bounds
cmp ax,[edi]
jb P.X.FIN
; X out of bounds - wrap
xor ax,ax; X to 0
inc cx; Y + 1
cmp cx,[edi+2]
jb P.X.FIN
; Y out of bounds - wrap
xor cx,cx; Y to 0

; Process result (make proper COORD structure)
P.X.FIN:
mov dx,ax; X to DX
mov ax,cx; Y to AX
shl eax,16; Y to high part of register
mov ax,dx; X to low part of register

pop edi

Ret


; => Prepare Y <=
; Converts user defined structure to a proper cursor position.
; Structure is [=][+][-]Y, e.g. '=0' or '+6'
; IN:
;       ESI = [POINTER] User defined structure
; OUT:
;       EAX = [DWORD] COORD structure
PREPARE.Y:

push edi

Call ACQUIRE.CON.SCR.BUF; EDI = Current screen buffer info

; Acquire control char and save it for CALCULATE.SIMPLE
Call ACQUIRE.CHAR
push eax

; Convert to proper binary form and call CALCULATE.SIMPLE
Call CONVERT.DECIMAL.STRING.TO.INTEGER
xor ecx,ecx
mov cx,[edi+6]; ECX = LHS: current Y for CSBI structure
mov edx,eax; EDX = RHS: specified by user
pop eax; EAX = Mode for CALCULATE.SIMPLE
Call CALCULATE.SIMPLE
mov cx,[edi+4]
; AX = New Y value
; CX = Old X value
; [EDI] = Max X value
; [EDI+2] = Max Y value

; Wrap if X/Y is out of bounds
cmp ax,[edi+2]
jb P.Y.FIN
; Y out of bounds - wrap
xor ax,ax; Y to 0
inc cx; X + 1
cmp cx,[edi]
jb P.Y.FIN
; X out of bounds - wrap
xor cx,cx; X to 0

; Process result (make proper COORD structure)
P.Y.FIN:
shl eax,16; Y to high part of register
mov ax,cx; X to low part of register

pop edi

Ret


; => Set cursor position <=
; IN:
;       EAX = [DWORD] COORD structure
SET.CURSOR.POS:

; Check if we are working with current cursor position or internal
cmp [ebp-M_GLOBAL_CURSOR],bl
jne S.C.P.INTERNAL

push eax;2; X and Y
push dword [ebp-118];1; EBP-118 = hndOut
Call [SetConsoleCursorPosition];:2

Ret

; Set internal cursor position
S.C.P.INTERNAL:

mov [ebp-44],eax

Ret


; => Set cursor size and visibility <=
; IN:
;       INDIRECTLY: Uses CSV structure
SET.CURSOR.SIZE.AND.VISIBILITY:

; Call API
push CSV;2; Cursor structure
push dword [ebp-118];1; EBP-118 = hndOut
Call [SetConsoleCursorInfo];:2

Ret


; => Update internal cursor position <=
UPDATE.INTERNAL.CURSOR.POS:

Call ACQUIRE.CON.SCR.BUF

mov ecx,[ebp-12]; Pointer: CSBI
mov ax,[ecx+6]; Y
shl eax,16
mov ax,[ecx+4]; X

mov [ebp-44],eax

Ret
