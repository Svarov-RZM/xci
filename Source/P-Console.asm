; P-Console.asm
;
; Copyright (c) 2019, Dmitry Razumovsky (Svarov-RZM)
; You may distribute under the terms of BSD 2-Clause License
; as specified in the LICENSE.TXT file.
;
; >>>=== CONSOLE PROCEDURES ===<<<
; => Get pointer to system arguments <=
; OUT:
;       ESI = [POINTER] Arguments
ACQUIRE.ARG.POINTER:

Call [GetCommandLineW];:0
mov esi,eax

Ret


; => Get CSBI structure <=
; IN: VOID
; OUT:
;       EDI = [POINTER] Screen buffer info
ACQUIRE.CON.SCR.BUF:

mov edi,[ebp-12]; CONSOLE_SCREEN_BUFFER_INFO structure
push edi;2
push dword [ebp-118];1; EBP-118 = hndOut
Call [GetConsoleScreenBufferInfo];:2

Ret


; => Create console buffer <=
; OUT:
;       EAX = [HANDLE] Console buffer
CREATE.CONSOLE.BUFFER:

push ebx;5; Reserved, null
push CONSOLE_TEXTMODE_BUFFER;4; dwFlags
push ebx;3; SA, null
push ebx;2; Buffer can't be shared
push GENERIC_READ+GENERIC_WRITE;1; Open for read/write
Call [CreateConsoleScreenBuffer]

Ret


; => Get console mode <=
; IN:
;       ECX = [HANDLE] Console
; OUT:
;       EAX = [INT] Console mode, see https://docs.microsoft.com/en-us/windows/console/setconsolemode
GET.CONSOLE.MODE:

sub esp,4

push esp;2; lpMode
push ecx;1; hConsoleHandle
Call [GetConsoleMode]

pop eax

Ret


; => Init internal console variables <=
; Color, cursor position and DBOX structure
; IN:
;       EDI = [POINTER] CSBI
INIT.INTERNAL.CONSOLE.STATE:

; Internal variables
xor eax,eax
mov ax,[edi+8]; CSBI: EDI+8 = Color
mov [ebp-74],eax; Current color
mov eax,[edi+4]; CSBI: Cursor position
mov [ebp-44],eax; EBP-44 - cursor position of current thread

Call RESET.DBOX; DBOX structure

Ret


; => Preserve CSBI structure <=
; IN:
;       EDI = [POINTER] CSBI
PRESERVE.CON.SCR.BUF:

mov esi,edi; ESI = Copy what: Current CSBI
mov edi,CSBI; Copy where: Backup CSBI
mov ecx,22; Size of CSBI structure
Call COPY.MEM.GENERAL

Ret


; => Adjust position according to DBOX structure <=
; IN:
;       ECX = [INT] Total counter of data to write
; OUT:
;       EAX = [DWORD] Current cursor position
;       ECX = [INT] Counter: Not greater than row
ADJUST.TO.DBOX:

Call CORRECT.POS.TO.DBOX; Returns position in EAX
push eax; Save position
Call RETURN.ROW.REST; EAX = Rest of row size

; Compare with counter
cmp ecx,eax
jl A.T.D.NOPE; ECX <= EAX which means no correction needed
sub ecx,eax
xchg ecx,eax
jmp short A.T.D.END

; Counter is equal or less than row size
A.T.D.NOPE:
xor eax,eax

A.T.D.END:
mov [ebp-524],eax
pop eax; Restore current cursor position

Ret


; => Copy arguments from system buffer to internal <=
; IN:
;       ESI = [POINTER] Arguments
;       EDI = [POINTER] Internal buffer [PRESERVED]
; OUT:
;       AL = 0 - Error, !=0 - Success
;       ECX = [INT] Length of arguments array
COPY.ARGS:

; Search for argument symbol
Call COUNT.STRING
xor dh,dh
mov dl,[ebp]; Symbol to look for, default: '/'
Call SEARCH.WORD
test al,al
je C.A.RET; Didn't find '/' symbol, no arguments?

; Save arguments in a new buffer
push edi
push ecx; Save length of arguments
Call COPY.MEM.WORDS; Now copying
mov [edi],ebx; Remove possible trash
pop ecx; Restore length of arguments
pop edi

C.A.RET:
Ret


; => Flush console input buffer <=
; IN:
;       EAX = [HANDLE] Input buffer
FLUSH.CONSOLE.INPUT:

; Call API
push eax;1; hConsoleInput
Call [FlushConsoleInputBuffer]

Ret


; => Prepare arguments in our buffer <=
; IN:
;       ESI = [POINTER] Arguments [PRESERVED]
;       ECX = [INT] Length of arguments array
; OUT:
;       ESI = [POINTER] End of arguments array
;       EAX = [POINTER] Start of arguments array
PREPARE.ARGUMENTS:

push esi

; Set up callback
xor dh,dh
mov dl,[ebp]; Char to look for, default: '/'
mov eax,P.A.CALLBACK

Call LOOP.OVER.MATCHED.CHARS

pop esi

Ret

; Searching for control symbol
; We'll constantly mess with ESI
; so we have to save/restore it on every iteration
P.A.CALLBACK:

push esi

; Check for exclude character
Call ACQUIRE.WORD.BACKWARD
cmp ax,[ebp-4]; Exclude symbol
je P.A.CORR

; Replace ' /.:' to NULL
Call ADD.NULL.TERMINATOR
Call SKIP.CHAR.FORWARD
Call ADD.NULL.TERMINATOR
mov ecx,2
Call SKIP.CHARACTERS
Call ADD.NULL.TERMINATOR

jmp short P.A.NEXT

; Perform correction for exclude argument
P.A.CORR:
mov ecx,1
Call COLLAPSE.NT.STRING
Call SKIP.CHAR.FORWARD
; We collapsed string by 1 character, so we have
; to tell about it to parent LOOP.OVER.MATCHED.CHARS procedure
dec dword [esp+12]

; Search for next char
P.A.NEXT:
pop esi
mov al,1
Ret


; => Put a character into console input buffer <=
; IN:
;       EAX = [CHAR]
;       EDX = [DWORD] Event: KEY_UP/DOWN
;       CX = [KEY]
;       ESI = [POINTER] Place for input structure
; OUT:
;       ESI = [POINTER] Next position
PUT.CHAR.TO.CONSOLE.INPUT:

; Put header
mov word [esi],KEY_EVENT

; Skip DWORD (KEY_EVENT+Alignment)
add esi,4

; Put event: DOWN/UP
mov dword [esi],edx
add esi,4

; Repeat count
mov [esi],bx
add esi,2

; Virtual key code
mov [esi],cx
add esi,2

; Virtual scan code
mov [esi],bx
add esi,2

; Unicode char
mov [esi],ax
add esi,2

; dwControlKeyState
mov [esi],ebx
add esi,4

Ret


; => Copy chars and attributes from shadow console buffer to current <=
; This procedure reads the full DBOX intro memory.
; So, if DBOX is 0,5,0,10, then 50 chars/attributes will be read
; IN:
;       EDI = [POINTER] Place to read
COPY.FROM.SHADOW.BUFFER:

push esi

; Copy DBOX to SMALL_RECT
mov esi,[ebp-82]; ESI = Pointer: DBOX
mov ax,[esi]; X [left]
mov [edi],ax
mov ax,[esi+4]; Y [top]
mov [edi+2],ax
mov ax,[esi+2]; X [right]
mov [edi+4],ax
mov ax,[esi+6]; Y [bottom]
mov [edi+6],ax
mov [edi+8],ebx; Clear possible trash in memory
push edi; Save SMALL_RECT pointer
add edi,12; Skip SMALL_RECT structure

; Set up Size of our buffer
mov dx,[esi+6]; DX = Y [bottom]
mov cx,[esi+2]; CX = X [right]
sub dx,[esi+4]; DX = subtract Y [top]
sub cx,[esi]; CX = subtract X [left]
; In DBOX we draw inclusively, so Y=0,3 equals to 4 columns
inc dx
inc cx
; Make proper COORD structure
shl edx,16; Y to HIGH part
mov dx,cx; EDX = COORD structure

; Save parameters for write call
pop esi; SMALL_RECT to ESI
push edx

; Read output
push esi;5; SMALL_RECT
push ebx;4; X & Y of our buffer
push edx;3; Size of our buffer
push edi;2; Read where
push dword [ebp-118];1; EBP-118 = hndOut
Call [ReadConsoleOutputW];:5

; Restore parameters for write call
pop edx

; Write output
push esi;5; SMALL_RECT
push ebx;4; X & Y of our buffer
push edx;3; Size of our buffer
push edi;2; Write from where
push dword [HND.STD.OUT];1; Original buffer
Call [WriteConsoleOutputW];:5

pop esi

Ret


; => Reset DBOX structure to defaults <=
RESET.DBOX:

mov eax,[ebp-82]; EAX = Pointer: DBOX
mov ecx,[ebp-12]; ECX = Pointer: CSBI

; ROW: Left = 0
mov [eax],bx

; ROW: Right
add eax,2
mov dx,[ecx]; Row size
dec dx; Inclusive. E.g. Row size 85 means 0..84 for us
mov [eax],dx

; COLUMN: Top = 0
add eax,2
mov [eax],bx

; COLUMN: Bottom
add eax,2
add ecx,2
mov dx,[ecx]; Column size
dec dx; Y-1 or we won't be able to correctly set position
mov [eax],dx

Ret


; => Return row size <=
; OUT:
;       EAX = [INT] Row size
RETURN.ROW:

mov eax,[ebp-82]; Pointer: DBOX
mov eax,[eax]; Row size
; Remove column from EAX
shl eax,16
shr eax,16

Ret


; => Return rest of row size <=
; Returns rest of the row size based on current cursor position
; IN:
;       EAX = [DWORD] COORD: Cursor position
; OUT:
;       EAX = [INT] Rest of row size
RETURN.ROW.REST:

mov edx,[ebp-82]; Pointer: DBOX
mov dx,[edx+2]; Value: DBOX: X [right]
inc dx; +1 because inclusive: 0..2 = 3 chars
xchg eax,edx
sub ax,dx
; Remove column from EAX
shl eax,16
shr eax,16
; Correct if AX = 0
test ax,ax
jne R.R.R.RET
inc ax

R.R.R.RET:
Ret


; => Read any <=
; Read any message that OS handles us
; IN: VOID - Procedure uses read buffer
; OUT:
;       ESI = Pointer: Custom read structure depending on type:
;               KEY: [+0w]Event [+2w]UP/DOWN [+4w]Scan key [+6w] Localized character
;               MOUSE: [+0w]Event [+2w]Type: double click/moved/etc. [+4w]Mouse key if single click [+8w] Mouse COORD
READ.ANY:

; Correct console mode (read mouse)
mov eax,ENABLE_MOUSE_INPUT+ENABLE_EXTENDED_FLAGS
mov ecx,[ebp-122]; hndStdIn
Call SET.CONSOLE.MODE

; Prepare buffers for reading
sub esp,4; LOCAL: lpNumberOfCharsRead
mov esi,[ebp-52]; Global read buffer
mov edi,esi
add edi,MAX_READ/2; Resulting structure is here

; Read an event
R.A.LOOP:
mov eax,esp
push eax;4; lpNumberOfEventsRead
push 1; 3; nLength
push esi; 2; lpBuffer
push dword [ebp-122];1; hConsoleInput
Call [ReadConsoleInputW]

; Make a proper structure
mov ax,[esi]
add esi,C_DWORD
cmp ax,KEY_EVENT
je R.A.KEY
cmp ax,MOUSE_EVENT
je R.A.MOUSE
cmp ax,FOCUS_EVENT
je R.A.CONTINUE
cmp ax,MENU_EVENT
je R.A.CONTINUE
cmp ax,WINDOW_BUFFER_SIZE_EVENT
je R.A.CONTINUE
jmp short R.A.LOOP; Unsupported event

; Set up key event
R.A.KEY:
mov word [edi],1; 1 = KEY
mov eax,[esi]; Key UP/DOWN
mov word [edi+2],ax
mov ax,[esi+6]; ScanKey
mov word [edi+4],ax
mov ax,[esi+8]; Char
mov word [edi+6],ax
jmp short R.A.RET

; Set up mouse event
R.A.MOUSE:

mov word [edi],2; 2 = MOUSE

; Let's figure out the event first
mov eax,[esi+12]; dwEventFlags
cmp eax,MOUSE_MOVED
je R.A.M.MOVED
cmp eax,DOUBLE_CLICK
je R.A.M.DBCLK

; None of the above, perhaps a single button click?
mov eax,[esi+4]; dwButtonState
cmp eax,ebx
jne R.A.M.CLK
jmp short R.A.CONTINUE; Unsupported event

; Mouse has been moved
R.A.M.MOVED:
mov word [edi+2],1
jmp short R.A.M.POS

; Single click occurred
R.A.M.CLK:
mov word [edi+2],2
mov [edi+4],eax
jmp short R.A.M.POS

; Double click
R.A.M.DBCLK:
mov word [edi+2],3

; Set mouse position
R.A.M.POS:
mov eax,[esi]; Mouse position in COORD structure (two words for X/Y)
mov [edi+8],eax
jmp short R.A.RET

; Continue?
R.A.CONTINUE:
mov esi,[ebp-52]; Global read buffer
jmp R.A.LOOP

; Cleaning up
R.A.RET:

; Restore original mode
mov eax,[MODE.STD.IN]
mov ecx,[ebp-122]; hndStdIn
Call SET.CONSOLE.MODE

add esp,4

Ret


; => Read chars <=
; Read specified amount of chars
; IN:
;       ECX = [COUNTER] How many characters to read
;       ESI = [POINTER] Buffer where to save chars [PRESERVED]
; OUT:
;       ESI = [POINTER] Array of characters read
READ.CHARS:

push esi

; Clear console mode, so we don't wait for a line
push ecx
xor eax,eax
mov ecx,[ebp-122]; hndStdIn
Call SET.CONSOLE.MODE
pop ecx

; Prepare callback
mov eax,R.C.PROCESS.CHAR
Call LOOP.TIMES

; Restore original mode
mov eax,[MODE.STD.IN]
mov ecx,[ebp-122]; hndStdIn
Call SET.CONSOLE.MODE

; Skip adding NT if we were interrupted
cmp [READ.CANCEL],bl
jne R.C.RET

Call ADD.NULL.TERMINATOR

R.C.RET:
pop esi

Ret

; CALLBACK: Read and process one character at a time
R.C.PROCESS.CHAR:

sub esp,4; LOCAL: lpNumberOfCharsRead
mov eax,esp

push ebx;5; pInputControl
push eax; 4; lpNumberOfCharsRead
push 1; 3; nNumberOfCharsToRead
push esi; 2; lpBuffer
push dword [ebp-122];1; hConsoleInput
Call [ReadConsoleW]
add esp,4

; Break on timeout
cmp [READ.CANCEL],bl
je R.C.P.C.NEXT
xor al,al
Ret

R.C.P.C.NEXT:
Call SKIP.CHAR.FORWARD
mov al,1

Ret


; => Read keys <=
; Read specified amount of keys pressed
; IN:
;       ECX = [COUNTER] How many keys to read
;       ESI = [POINTER] Buffer where to save keys [PRESERVED]
;       EDI = [POINTER] Temp buffer where to put INPUT_RECORD
; OUT:
;       ESI = [POINTER] Array of keys read
READ.KEYS:

push esi

; Prepare callback
mov eax,R.K.PROCESS.KEY
Call LOOP.TIMES

; Skip adding NT if we were interrupted
cmp [READ.CANCEL],bl
jne R.K.RET

Call ADD.NULL.TERMINATOR

R.K.RET:
pop esi

Ret

; CALLBACK: Read and process one key at a time
R.K.PROCESS.KEY:

sub esp,4; LOCAL: lpNumberOfCharsRead
mov eax,esp

; Read an event
push eax;4; lpNumberOfEventsRead
push 1; 3; nLength
push edi; 2; lpBuffer
push dword [ebp-122];1; hConsoleInput
Call [ReadConsoleInputW]
add esp,4

; Break on timeout
cmp [READ.CANCEL],bl
je R.K.P.K.NEXT
xor al,al
Ret

; We only process KEY_EVENTs
R.K.P.K.NEXT:
cmp word [edi],KEY_EVENT
je R.K.P.K.KEY

; Not a key
; We increment counter of LOOP.TIMES so it'll run us again
R.K.P.K.SKIP:
inc dword [esp+8]
mov al,1
Ret

; Got key, process only if it's KEY_DOWN
; [EDI+14] = Scan code (wVirtualScanCode)
R.K.P.K.KEY:
cmp [edi+4],ebx
je R.K.P.K.SKIP
mov ax,[edi+10]
mov [esi],ax

Call SKIP.CHAR.FORWARD
mov al,1

Ret


; => Read lines <=
; Read specified amount of lines
; IN:
;       AX = [WORD] Mode: 'N' = Do not echo back, 'E' = Do echo chars back
;       ECX = [INT] Number of lines to read
;       ESI = [POINTER] Buffer where to save chars [PRESERVED]
; OUT:
;       ESI = [POINTER] Array of characters read
READ.LINES:

push esi

; Check what mode we are working in
; EDX is resulted mode
mov edx,ENABLE_LINE_INPUT+ENABLE_PROCESSED_INPUT
cmp al,'E'
jne R.L.SET.CONSOLE
add edx,ENABLE_ECHO_INPUT

; Set console mode
R.L.SET.CONSOLE:
push ecx
mov eax,edx
mov ecx,[ebp-122]; hndStdIn
Call SET.CONSOLE.MODE
pop ecx

; Prepare callback
mov eax,R.L.PROCESS.LINE
Call LOOP.TIMES

; Restore original mode
mov eax,[MODE.STD.IN]
mov ecx,[ebp-122]; hndStdIn
Call SET.CONSOLE.MODE

; Skip adding NT if we were interrupted
cmp [READ.CANCEL],bl
jne R.L.RET

Call ADD.NULL.TERMINATOR

R.L.RET:
pop esi

Ret

; CALLBACK: Read and process one line at a time
R.L.PROCESS.LINE:

sub esp,4; LOCAL: lpNumberOfCharsRead
mov eax,esp

push ebx;5; pInputControl
push eax; 4; lpNumberOfCharsRead
push MAX_READ; 3; nNumberOfCharsToRead
push esi; 2; lpBuffer
push dword [ebp-122];1; hConsoleInput
Call [ReadConsoleW]
mov ecx,[esp]
add esp,4

; Break on timeout
cmp [READ.CANCEL],bl
je R.L.P.L.NEXT
xor al,al
Ret

R.L.P.L.NEXT:
Call SKIP.CHARACTERS
mov al,1

Ret


; => Set console mode <=
; IN:
;       EAX = [INT] Console mode, see https://docs.microsoft.com/en-us/windows/console/setconsolemode
;       ECX = [HANDLE] Console handle
SET.CONSOLE.MODE:

push eax;2
push ecx;1
Call [SetConsoleMode]

Ret


; => Set current console color <=
; IN:
;       EAX = [INT] Color attribute
SET.CURRENT.COLOR:

push eax;2
push dword [ebp-118];1; EBP-118 = hndOut
Call [SetConsoleTextAttribute];:2

Ret


; => Set DBOX to window size <=
SET.DBOX.TO.WINDOW.SIZE:

mov eax,[ebp-82]; EAX = Pointer: DBOX
mov ecx,[ebp-12]; ECX = Pointer: CSBI

; ROW: Left = 0
mov [eax],bx

; ROW: Right
add eax,2
mov dx,[ecx+14]; Window's MAX row size
mov [eax],dx

; COLUMN: Top = 0
add eax,2
mov [eax],bx

; COLUMN: Bottom
add eax,2
mov dx,[ecx+16]; Window's MAX column size
mov [eax],dx

Ret


; => Transform a simple text to a full line of row size <=
; IN:
;       EAX = [DWORD] COORD: For proper formatting of text inside the line
;       ECX = [INT] Size of text
;       ESI = [POINTER] Text
; OUT: VOID
TRANSFORM.TEXT.INTO.LINE:

; Preserve needed parameters
sub esp,4; New counter will be here (LINE)
push ecx
push eax
push esi

; Skip current text
Call SKIP.NT.STRING

; Get proper row size in EAX
mov edx,[ebp-82]; Pointer: DBOX
xor ecx,ecx
mov cx,[edx+2]; X [right]
inc cx; +1 because inclusive: 0..2 = 3 chars
sub cx,[edx]; X [left]
mov [esp+12],ecx

; Draw line in memory
; EDI will point to expanded line
mov edi,esi
push edi
Call PREPARE.LINE
pop edi; Expanded line
pop esi; Original text

; Skip characters in line in case of formatting
pop eax; COORD
xor ecx,ecx
mov cx,ax
mov eax,[ebp-82]; Pointer: DBOX
sub cx,[eax]; Add shift from left side if any
Call SKIP.CHARACTERS.DST

; Copy string
pop ecx
Call COPY.CHARACTERS

; Restore counter and get proper pointer to text
pop ecx
Call SKIP.CHAR.FORWARD

Ret


; => Write console attributes <=
; IN:
;       ESI = [POINTER] Attributes
;       ECX = [INT] Size of attributes
WRITE.CONSOLE.ATTRIBUTES:

sub esp,4; Temp output for API

; Work with internal console buffer
; We'll reset it in the end
mov byte [ebp-M_GLOBAL_CURSOR],1

; Check if counter = zero
test ecx,ecx
je W.C.A.END

; Write given output line by line according to row/column
W.C.A.LOOP:
Call ADJUST.TO.DBOX

; Save current cursor position and set up temp pointer for attributes written
mov edx,esp
push eax

; Call API
push edx;5; Attributes written
push eax;4; X & Y
push ecx;3; Counter
push esi;2; Buffer with colors
push dword [ebp-118];1; EBP-118 = hndOut
Call [WriteConsoleOutputAttribute];:5

; Update current cursor position
pop eax
add ax,[esp]
Call SET.CURSOR.POS

; Skip amount characters we wrote
mov ecx,[esp]
Call SKIP.CHARACTERS

; Check if we still have something to write
cmp [ebp-524],ebx
je W.C.A.END

; Correct counter and continue
mov ecx,[ebp-524]
jmp short W.C.A.LOOP

; Clear stack, reset internal position and return
W.C.A.END:
mov [ebp-M_GLOBAL_CURSOR],bl
add esp,4
Ret


; => Write console input <=
; IN:
;       ECX = [INT] Number of INPUT_RECORD entries
;       ESI = [POINTER] INPUT_RECORDs
WRITE.CONSOLE.INPUT:

sub esp,4

; Call API
push esp;4; lpNumberOfEventsWritten
push ecx;3; nLength
push esi;2; lpBuffer
push dword [ebp-122];1; hConsoleInput
Call [WriteConsoleInputW];:4

add esp,4

Ret


; => Write output to console <=
; We write line by line and adjust cursor position manually
; IN:
;       ESI = [POINTER] Data to write
;       ECX = [INT] Size of data in chars
; OUT:
;       EAX = [INT] Chars written
WRITE.TO.CONSOLE:

sub esp,4; Temp output buffer for API and size

; Break if counter equals zero
test ecx,ecx
je W.T.C.END

; Write given output line by line according to row/column
W.T.C.LOOP:
Call ADJUST.TO.DBOX

; Fill the line before writing if set
cmp [ebp-M_T_FILL_LINE],bl
je W.T.C.L.CALL

; Transform line
; We need to save cursor position before call and new string counter after
push eax
Call TRANSFORM.TEXT.INTO.LINE
pop eax
push ecx

; Now restore cursor and set X to 0
; because we write by whole line
mov edx,[ebp-82]; Pointer: DBOX
mov ax,[edx]; X [left]
Call SET.CURSOR.POS
pop ecx

; Call API
W.T.C.L.CALL:
mov eax,esp; Pointer for ;4
push ebx;5; Reserved
push eax;4; How many symbols were written
push ecx;3; Counter
push esi;2; Buffer
push dword [ebp-118];1; Console handle
Call [WriteConsoleW];:5

; Skip amount of characters we wrote
mov ecx,[esp]
Call SKIP.CHARACTERS

; Check if we still have something to write
cmp [ebp-524],ebx
je W.T.C.END

; Correct counter and continue
mov ecx,[ebp-524]
jmp short W.T.C.LOOP

; Finalizing
W.T.C.END:
pop eax; EAX = Chars written
Ret


; => Write output to console without moving the cursor <=
; We write line by line but do not adjust position
; What is important here is that we MUST write attributes and text separately
; IN:
;       ESI = [POINTER] Data to write
;       ECX = [INT] Size of data in bytes
; OUT:
;       EAX = [INT] Bytes written
WRITE.TO.CONSOLE.NO.ADJ:

; Set up room for attributes
mov edi,esi
add edi,MAX_BUFFER/2
push edi; Save pointer to attributes [EDI]
sub esp,4; Temp output buffer for API and size

; Break if counter equals zero
test ecx,ecx
je W.T.C.N.A.END

; Write given output line by line according to row/column
W.T.C.N.A.LOOP:
Call ADJUST.TO.DBOX

; Fill color attributes first
mov edi,[esp+4]; Restore pointer to attributes
push ecx; Preserve characters counter
push eax; Preserve COORD
mov eax,[ebp-74]; Color to fill with
Call FILL.WORDS
mov edi,eax; EDI = Start of buffer filled with attributes
mov eax,[esp]; EAX = COORD
mov ecx,[esp+4]; ECX = Counter

; Write attributes
sub esp,4; Temp output buffer for API
mov edx,esp; Pointer for ;5
push edx;5; How many attributes were written
push eax;4; X & Y
push ecx;3; Count
push edi;2; Buffer with colors
push dword [ebp-118];1; Console handle
Call [WriteConsoleOutputAttribute];:5
add esp,4; Remove temp output buffer for API
pop eax; Restore COORD
pop ecx; Restore counter

; Write characters
mov edx,esp; Pointer for ;5
push edx;5; How many symbols were written
push eax;4; COORD X Y
push ecx;3; Counter
push esi;2; Buffer
push dword [ebp-118];1; hndOut
Call [WriteConsoleOutputCharacterW];:5

; Skip amount characters we wrote
mov ecx,[esp]
Call SKIP.CHARACTERS

; Check if we still have something to write
cmp [ebp-524],ebx
jne W.T.C.N.A.LOOP

; Finalizing
W.T.C.N.A.END:
pop eax; EAX = Chars written
add esp,4; Remove pointer for attributes
Ret


; => Set console output code page <=
; IN:
;       EAX = Code page number
SET.OUTPUT.CP:

push eax;1
Call [SetConsoleOutputCP];:1

Ret