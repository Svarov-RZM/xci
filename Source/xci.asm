; xci.asm
;
; Copyright (c) 2019, Dmitry Razumovsky (Svarov-RZM)
; You may distribute under the terms of BSD 2-Clause License
; as specified in the LICENSE.TXT file.
BITS 32
CPU 386
global start


; >>>=== EXTERNAL API ===<<<
extern ExitProcess
extern ExitThread
extern GetCommandLineW
extern WriteFile
extern GetStdHandle
extern GetFileSize
extern GetConsoleScreenBufferInfo
extern SetConsoleTextAttribute
extern GetConsoleMode
extern FlushConsoleInputBuffer
extern SetConsoleMode
extern Sleep
extern SetConsoleCursorPosition
extern WriteConsoleOutputW
extern WriteConsoleOutputCharacterW
extern CreateFileW
extern ReadFile
extern CreateEventW
extern CloseHandle
extern ConnectNamedPipe
extern CreateNamedPipeW
extern CreateThread
extern DisconnectNamedPipe
extern WriteConsoleOutputAttribute
extern SetConsoleOutputCP
extern GetConsoleCursorInfo
extern SetConsoleCursorInfo
extern GetProcessHeap
extern HeapAlloc
extern HeapFree
extern ReadConsoleW
extern ReadConsoleInputW
extern ReadConsoleOutputW
extern GetCurrentThread
extern CreateConsoleScreenBuffer
extern SetEvent
extern WaitForSingleObject
extern MultiByteToWideChar
extern WriteConsoleW
extern WriteConsoleInputW


; >>>=== CONSTANTS ===<<<
; SYSTEM SPECIFIC
FILE_ATTRIBUTE_NORMAL EQU 80h
OPEN_EXISTING EQU 3
GENERIC_READ EQU 80000000h
GENERIC_WRITE EQU 40000000h
EV_RXFLAG EQU 2h
STD_INPUT_HANDLE EQU -10
STD_OUTPUT_HANDLE EQU -11
STD_ERROR_HANDLE EQU -12
ENABLE_PROCESSED_OUTPUT EQU 1h
ENABLE_WRAP_AT_EOL_OUTPUT EQU 2h
ENABLE_ECHO_INPUT EQU 4h
PIPE_TYPE_BYTE EQU 0h
PIPE_WAIT EQU 0h
ENABLE_PROCESSED_INPUT EQU 1h
INFINITE EQU -1
WM_MKMF EQU 421h
FILE_ATTRIBUTE_TEMPORARY EQU 100h
FILE_SHARE_READ EQU 1h
FILE_SHARE_WRITE EQU 2h
CREATE_ALWAYS EQU 2
KEY_EVENT EQU 1h
FROM_LEFT_1ST_BUTTON_PRESSED EQU 1h
MOUSE_EVENT EQU 2h
MOUSE_MOVED EQU 1h
MOUSE_WHEELED EQU 0004h
ENABLE_MOUSE_INPUT EQU 10h
ENABLE_LINE_INPUT EQU 2h
STATUS_WAIT_0 EQU 00000000h
STATUS_TIMEOUT EQU 00000102h
WAIT_TIMEOUT EQU STATUS_TIMEOUT
WAIT_OBJECT_0 EQU STATUS_WAIT_0
CONSOLE_TEXTMODE_BUFFER EQU 1
PIPE_ACCESS_DUPLEX EQU 3
CP_ACP EQU 0
CP_OEMCP EQU 1
CP_UTF8 EQU 65001
FOCUS_EVENT EQU 10h
MENU_EVENT EQU 8h
WINDOW_BUFFER_SIZE_EVENT EQU 4h
DOUBLE_CLICK EQU 2h
ENABLE_EXTENDED_FLAGS EQU 0080h

; PROGRAM SPECIFIC
; Array containing different program-specific structures
MAX_ARGUMENTS EQU 8192; Arguments array
MAX_BUFFER EQU 8192; Buffer for argument processing
MAX_READ EQU 1024; All read procedures use it exclusively
MAX_THREADS EQU 32; Max. threads. One thread = One pointer
MAX_CSBI EQU 22; CSBI structure
MAX_DBOX EQU 8; DBOX structure (Drawing BOX)
MAX_LINE EQU 24; Line structure
MAX_VARS EQU 8192; Variable data
MAX_DATA_TOTAL EQU MAX_ARGUMENTS+MAX_BUFFER+MAX_READ+MAX_THREADS+MAX_CSBI+MAX_DBOX+MAX_LINE+MAX_VARS

; Version
VER_ARCH EQU 'A'
VER_MJ EQU 1
VER_MN EQU 0

; BASIC MACHINE STUFF
BASIC_REGISTER EQU 4; How many bytes in a common processor register
C_WORD EQU 2; Machine word
C_DWORD EQU 4; Machine double word
C_POINTER EQU 4; Size of a pointer

; NUMBERS AND COMPORISION PREFIXES
PREFIX_HEX EQU 00780030h; '0x' prefix
PREFIX_EQU EQU 00710065h; 'eq' prefix
PREFIX_NEQ EQU 0065006eh; 'ne' prefix
PREFIX_GEQ EQU 00650067h; 'ge' prefix
PREFIX_LEQ EQU 0065006ch; 'le' prefix
PREFIX_GTR EQU 00740067h; 'gt' prefix
PREFIX_LSS EQU 0074006ch; 'lt' prefix

; LOGIC MODIFIERS
; Located in EBP structure. Changed in /M procedure
M_SIZE EQU 14; Total size of flags
M_T_BASE EQU 272
        M_T_ADJUST_CURSOR EQU M_T_BASE
        M_T_FORMAT_ROW EQU M_T_BASE+1
        M_T_FORMAT_COLUMN EQU M_T_BASE+2
        M_T_COMPLEX_STRING EQU M_T_BASE+3
        M_T_COMPLEX_FORMAT EQU M_T_BASE+4
        M_T_FILL_LINE EQU M_T_BASE+5
M_L_BASE EQU 278
        M_L_DRAW_USING EQU M_L_BASE
M_A_BASE EQU 280
        M_A_RESERVED EQU M_A_BASE
M_P_BASE EQU 282
        M_P_CONVERT EQU M_P_BASE
M_GLOBAL_BASE EQU 284
        M_GLOBAL_CURSOR EQU M_GLOBAL_BASE
        M_GLOBAL_EXPAND_VAR EQU M_GLOBAL_BASE+1

; Text processing
UTF_CHAR_SIZE EQU 4; How many bytes in one UTF char

; Line drawing
; Where to save corresponding values in MAX_LINE buffer
; Start+0, Middle+LINE_OFFSET, End+LINE_OFFSET*2
LINE_OFFSET EQU 4; CHARS


; >>>=== UNDEFINATED SECTION ===<<<
segment .bss align=4
; => CONSOLE_SCREEN_BUFFER_INFO structure <=
; Located in heap. Each thread has their own copy.
; Pointer in [EBP-12]. Total size = 22 bytes
;+0: CSBI.SizeX resw 1, size of the console buffer - X
;+2: CSBI.SizeY resw 1, size of the console buffer - Y
;+4: CSBI.PosX resw 1, cursor position - X
;+6: CSBI.PosY resw 1, cursor position - Y
;+8: CSBI.Attr resw 1, attributes/color of the screen buffer
;+10: CSBI.WndCoord resd 2, coordinates of console buffer - left-top, right-bottom
;+18: CSBI.WndMaxX resw 1, max console window's size - X
;+20: CSBI.WndMaxY resw 1, max console window's size - Y

; => DBOX structure <=
; Initially located in heap. Additional copies in VARS.
; Pointer in [EBP-82]. Total size = 8 bytes
;+0: DBOX.ROW.LEFT resw 1
;+2: DBOX.ROW.RIGHT resw 1
;+4: DBOX.COLUMN.TOP resw 1
;+6: DBOX.COLUMN.BOTTOM resw 1

; => CONSOLE_SCREEN_BUFFER_INFO structure <=
; This one is a copy so we can always restore initial console settings
CSBI:; = 22 bytes
CSBI.SizeX resw 1; Size of the console buffer - X
CSBI.SizeY resw 1; Size of the console buffer - Y
CSBI.PosX resw 1; Cursor position - X
CSBI.PosY resw 1; Cursor position - Y
CSBI.Attr resw 1; Attributes/color of the screen buffer
CSBI.WndCoord resd 2; Coordinates of console buffer - left-top, right-bottom
CSBI.WndMaxX resw 1; Max console window's size - X
CSBI.WndMaxY resw 1; Max console window's size - Y

; => Cursor: S&V (Size and Visibility) <=
CSV:; = 8 bytes
CSV.S resd 1; SIZE
CSV.V resd 1; VISIBILITY

; => Console modes <=
CONMOD:; = 8 bytes
CONMOD.OUT resd 1; Console OUT mode
CONMOD.IN resd 1; Console IN mode

; => Process heap <=
HEAP resb MAX_DATA_TOTAL
HND.HEAP resd 1

; => Console stuff (handles/modes) <=
HND.STD.IN resd 1;q; Console input handle
HND.STD.OUT resd 1;q; Console output handle
MODE.STD.IN resd 1;q; Console mode STDIN
MODE.STD.OUT resd 1;q; Console mode STDOUT

; => System <=
CODE.EXIT resd 1;q; Exit code, set by /Q procedure
READ.CANCEL resb 1; Flag: Stop reading console if timeout is set
READ.EVENT resd 1;q; Handle: For sync between reading threads
READ.THREAD resd 1;q; Handle: Main reading thread

; => IN-STACK Structure <=
;       CAN CONTAIN TRASH AT START/MANUAL INITIALIZATION:
; EBP-0 - [CHAR] Argument
; EBP-4 - [CHAR] Exclude
; EBP-8 - [INT] Count of arguments array [STATIC]
; EBP-12 - [POINTER] CSBI structure
; EBP-16 - [INT] Maximum size for buffer-limited functions, such as CONVERT.BYTES.TO.WIDECHAR
; EBP-20 - [POINTER] MAX_ARGUMENTS [DYNAMIC]
; EBP-24 - [POINTER] MAX_BUFFER
; EBP-28 - [INT] Count of arguments array (MAX_ARGUMENTS) [DYNAMIC]
; EBP-32 - [POINTER] Last pointer from ALLOCATE.MEMORY procedure
; EBP-36 - [POINTER] Start of variable array (MAX_VARS)
; EBP-40 - [POINTER] End of variable array (MAX_VARS)
; EBP-44 - [DWORD] Internal cursor position. Used instead of system one if certain flag is set
; EBP-48 - [POINTER] MAX_ARGUMENTS [STATIC]
; EBP-52 - [POINTER] MAX_READ buffer
; EBP-56 - [UNASSIGNED]
; EBP-60 - [POINTER] MAX_LINE structure
; EBP-66 - [INT] Error level for current thread
; EBP-70 - [UNASSIGNED]
; EBP-74 - [INT] Current color
; EBP-78 - [POINTER] DBOX structure [default structure, STATIC]
; EBP-82 - [POINTER] DBOX structure [DYNAMIC]
; EBP-86-114 [UNASSIGNED]
; EBP-118 - [HANDLE] STD.OUT [DYNAMIC]
; EBP-122 - [HANDLE] STD.IN [DYNAMIC]
; EBP-126 - [UNASSIGNED]
; EBP-130 - [POINTER] Thread handles (MAX_THREADS). Separate threads aren't implemented yet
; EBP-134-256 - [UNASSIGNED]
;       SHOULD BE ZERO AT START
; EBP-260 - [HANDLE] MAIN or Thread? Contains handle if thread or NULL otherwise
; EBP-264 - [DWORD] SYSTEM FLAGS (flags that can't be directly changed by user):
;       [264] = Perform return after upper call in MAIN_LOOP
;       [265] = Holds flag that indicates should DRAW.INSIDE jmp or return
;       [266] = '@' will not store position in stack and will 'ret' instead of 'jmp' to MAIN
;       [267] = 'L' Will draw lines only in memory and then return instead of jump
; EBP-268 - [RESERVED] Future system flags might end up here
; EBP-272 - [6 BYTES] 'T' Modes:
;       [272] = Write mode:
;               =0 - Adjust cursor position
;               !=0 - DO NOT adjust cursor position
;       [273] = Format text in DBOX [ROW]:
;               'l' - left
;               'c' - center
;               'r' - right
;       [274] = Format text in DBOX [COLUMN]:
;               't' - top
;               'c' - center
;               'b' - bottom
;       [275] = Perform PROCESS.COMPLEX.STRING
;       [276] = Format on several /T arguments, number from 1 to 9
;       [277] = Fill the whole line by 'L' procedure before writing
; EBP-278 - [2 BYTES] 'L' Modes:
;       [278] = Draw line using [C]hars or [A]ttrs
;       [279] = RESERVED
; EBP-280 - [2 BYTES] 'A' Modes:
;       [280] = RESERVED
;       [281] = RESERVED
; EBP-282 - [2 BYTES] 'P' Pipe modes:
;       [282] - Convert read data (see CONVERT.BYTES.TO.WIDECHAR)
;       [283] - RESERVED
; EBP-284 - [2 BYTES] '#' GLOBAL procedure modes/flags:
;       [284] - Working with external[0]/internal[!0] cursor position
;       [285] = Perform EXPAND.VAR for procedures that support it ('T', 'A', 'L', ...)
; EBP-286-299 - [RESERVED] Future flags
; EBP-300 - [HANDLE] Secondary buffer handle
; EBP-304 - [HANDLE] Pipe handle
; EBP-308-512 - [UNASSIGNED]
;       TEMP PER THREAD BUFFER
; WARNING! This section will be eliminated in the future!
; EBP-516 - [DWORD] THREAD.READ holds default choice here
; EBP-520 - [UNASSIGNED]
; EBP-524 - [INT] ADJUST.TO.DBOX - Holds rest of the data counter
; EBP-528-768 [UNASSIGNED]


; >>>=== DEFINED SECTION ===<<<
segment .data align=4

; => MBI (Menu Based Interface) <=
MBI:; = 20 bytes
MBI.N.LEFT dw 25h
MBI.N.RIGHT dw 27h
MBI.N.UP dw 26h
MBI.N.DOWN dw 28h
MBI.E.PREVIOUS dd 0;p; Pointer to previously selected element
MBI.E.SELECTED dd 0;p; Pointer to currently selected element
MBI.E.EVENT dd 0;d; Current event for active element

; => MISC <=
NewLine db 0Dh,0,0Ah,0,0,0,0,0


; >>>=== CODE SECTION ===<<<
segment .code
start:

; Get global heap pointer
; Now we can allocate dynamic memory by calling ALLOCATE.MEMORY
Call ACQUIRE.HEAP.POINTER

; Set up registers and stack
; Allows us to use ebp as a pointer to above IN-STACK structure
Call INIT.THREAD.BASE

; Set up pointers and handles
; Now all IN-STACK pointers are valid
mov eax,HEAP
Call SETUP.POINTERS

; Console stuff, you know, STD IN/OUT, modes
Call OBTAIN.STD.HANDLES

; Get original color and basic screen buffer info
; After this, EDI = [POINTER] CSBI structure
Call ACQUIRE.CON.SCR.BUF

; Set initial console buffer state
; Current color, DBOX structure and cursor position
Call INIT.INTERNAL.CONSOLE.STATE

; Preserve original CSBI for later restore (if needed)
Call PRESERVE.CON.SCR.BUF

; Init CSV structure
; Cursor's size and visibility
Call ACQUIRE.CONSOLE.CURSOR

; Get pointer to system's argument buffer in ESI
Call ACQUIRE.ARG.POINTER

; Copy arguments from system buffer to internal
mov byte [ebp],'/'; Symbol for 'argument'
mov byte [ebp-4],'\'; Symbol for 'exclude'
mov edi,[ebp-20]; EDI = Place to save arguments
Call COPY.ARGS
; Exit on fail
test al,al
je EXIT

; Setup pointers to arguments and data buffers
mov [ebp-8],ecx; Counter of arguments array: Static
mov [ebp-28],ecx; Counter of arguments array: Dynamic
mov esi,eax; ESI = Pointer: Buffer with copied arguments

; Prepare arguments by removing '/' symbol and process exclude characters
Call PREPARE.ARGUMENTS

; Clear top of the stack
; MAIN.LOOP will return if it's not zero
mov [esp],ebx

; MAIN LOOP
; EBP-20 - always points to processed arguments
; EBP-24 - always points to an argument-processing buffer
MAIN.LOOP:

; Perform return if top of the stack contain pointers (not null)
; Upper logic may call another upper logic (e.g. PROCESS.L calls PROCESS.T)
; and request us to return except for continuing the usual flow
cmp [esp],ebx
je M.L.CONT
Ret

; Searching for next argument
M.L.CONT:
mov esi,[ebp-20]; Pointer: Arguments array
mov edi,[ebp-24]; Pointer: Temp buffer for processing
mov ecx,[ebp-28]; Counter: Rest of arguments array
Call SEARCH.NEXT.ARGUMENT
; Exit if no more arguments
test al,al
je EXIT.IF.NOT.PIPE

; Set up pointers and prepare data
mov [ebp-28],ecx; Counter: ARGS array
mov [ebp-20],esi; Pointer: Hopefully a next argument
Call COPY.NT.STR; Copy argument to temp buffer
mov esi,eax; Start of copied string
; Skip two chars in ARGS buffer
; Two because we have to skip something like this: /T or /C
mov ecx,2
Call SKIP.CHARACTERS.DST

; Check for action
; DX contains an UTF-16 character from SEARCH.NEXT.ARGUMENT call
cmp dl,'T'; Text output
je PROCESS.T
cmp dl,'N'; New line
je PROCESS.N
cmp dl,'C'; Color
je PROCESS.C
cmp dl,'S'; Sleep
je PROCESS.S
cmp dl,'X'; Cursor position: X
je PROCESS.X
cmp dl,'Y'; Cursor position: Y
je PROCESS.Y
cmp dl,'~'; Add/Modify variable
je PROCESS.TILDA
cmp dl,'?'; Checks upon variables
je PROCESS.CHK
cmp dl,'L'; Draw line
je PROCESS.L
cmp dl,'G'; Set code page
je PROCESS.G
cmp dl,'M'; Modify internal logic
je PROCESS.M
cmp dl,'A'; Attribute output
je PROCESS.A
cmp dl,'B'; Set DBOX structure
je PROCESS.B
cmp dl,'@'; Label and logic-flow management
je PROCESS.AT
cmp dl,'#'; Return from the last label call
je P.AT.RET
cmp dl,'V'; Cursor's size/visibility
je PROCESS.V
cmp dl,'b'; Console buffer management
je PROCESS.BB
cmp dl,'m'; Memory management
je PROCESS.MM
cmp dl,'R'; Read console input
je PROCESS.R
cmp dl,'W'; Write to different handles (specific)
je PROCESS.W
cmp dl,'F'; Register/draw frames
je PROCESS.F
cmp dl,'E'; Register/draw active elements
je PROCESS.E
cmp dl,'D'; Enter navigation mode and dispatch messages
je PROCESS.D
cmp dl,'x'; Execute xci script
je PROCESS.XX
cmp dl,'P'; Get arguments from pipe
je PROCESS.P
cmp dl,'Q'; Quit the program
je PROCESS.Q

; Possibility of reaching this point is very small.
; Typically, we reach this only if user specified an unknown argument.
; In this case we like, whatever, and processed to look for the next possible argument
jmp MAIN.LOOP
; NOTE: Every 'PROCESS.*' procedure operates on DATA buffer located in ESI


; => 'T' Text output <=
PROCESS.T:

; Perform variable expanding
mov al,[ebp-M_GLOBAL_EXPAND_VAR]
test al,al
je P.T.COMPLEX
Call EXPAND.STR.VAR

; Process complex string
P.T.COMPLEX:
mov al,[ebp-M_T_COMPLEX_STRING]
test al,al
je P.T.CNT
Call PROCESS.COMPLEX.STRING

; Count string
P.T.CNT:
Call COUNT.STRING

; Adjust position if we work with internal cursor
mov al,[ebp-M_T_ADJUST_CURSOR]
test al,al
jne P.T.DO.NOT.ADJUST
Call WRITE.TO.CONSOLE
jmp MAIN.LOOP

; Do not adjust position
P.T.DO.NOT.ADJUST:
Call WRITE.TO.CONSOLE.NO.ADJ
jmp MAIN.LOOP


; => 'N' New line [simulated] <=
PROCESS.N:

; The logic here is that we set Y to +1 and X to 0, then
; call to ADJUST.TO.DBOX to correct position according to DBOX
Call ACQUIRE.CON.SCR.BUF; EDI = Current screen buffer info
mov ax,[edi+6]; Y
inc ax; Y+1
shl eax,16; Y to high part
xor ax,ax; X = 0
Call SET.CURSOR.POS
Call ADJUST.TO.DBOX

jmp MAIN.LOOP


; => 'C' Set color <=
PROCESS.C:

Call EXPAND.STR.VAR

Call CONVERT.HEXADECIMAL.STRING.TO.INTEGER
mov [ebp-74],eax; New current color

Call SET.CURRENT.COLOR

jmp MAIN.LOOP


; => 'S' Sleep for ms <=
PROCESS.S:

Call CONVERT.DECIMAL.STRING.TO.INTEGER

Call SLEEP.MS

jmp MAIN.LOOP


; => 'X' change cursor position by X <=
; IN:
;       ESI = Structure for CALCULATE.SIMPLE like '+5'
PROCESS.X:

Call PREPARE.X
Call SET.CURSOR.POS

jmp MAIN.LOOP


; => 'Y' change cursor position by Y <=
; IN:
;       ESI = Structure for CALCULATE.SIMPLE like '+5'
PROCESS.Y:

Call PREPARE.Y
Call SET.CURSOR.POS

jmp MAIN.LOOP


; => '~' Set/Modify variable <=
PROCESS.TILDA:

Call MANAGE.VAR

jmp MAIN.LOOP


; => '@' Labels/Goto/Calls <=
PROCESS.AT:

Call ACQUIRE.CHAR

; Check possible actions
cmp al,')'; Unconditional goto
je P.AT.GOTO
cmp al,'('; Unconditional call
je P.AT.CALL
cmp al,']'; Conditional goto
je P.AT.CGOTO
cmp al,'['; Conditional call
je P.AT.CCALL
cmp al,'='; Save procedure label for '(' call
je P.AT.SAVE
cmp al,'!'; Simple label - not a procedure, goto ')'
je P.AT.SAVE
jmp MAIN.LOOP; Just a label. No need for processing

; Evaluate condition
P.AT.CGOTO:
Call CANCEL.IF.FALSE
test al,al
je MAIN.LOOP
jmp short P.AT.GOTO

P.AT.CCALL:
Call CANCEL.IF.FALSE
test al,al
je MAIN.LOOP
jmp short P.AT.CALL

; GOTO statement
P.AT.GOTO:

; Try to get a previously saved pointer ('=' call)
Call GET.LABEL.VARIABLE
test esi,esi
je EXIT

; Correct arguments structure
mov [ebp-28],ecx; Counter of ARGS array [dynamic]
mov [ebp-20],esi; Current ARGS pointer [dynamic]

jmp MAIN.LOOP

; CALL statement
; Save current ARGS position
; We skip it in special cases (e.g. called from 'D')
P.AT.CALL:
cmp [ebp-266],bl
jne P.AT.C.ADD.NP

; We save pointer to current ARGS, counter and also NULL pointer.
; This is needed so MAIN.LOOP won't return to the last address on stack
P.AT.C.SAVE.POS:
push dword [ebp-20]; Point of return after procedure call
push dword [ebp-28]; Counter of ARGS array [current]
P.AT.C.ADD.NP:
push ebx

; Try to get a previously saved pointer ('=' call)
Call GET.LABEL.VARIABLE
test esi,esi
je EXIT

; Correct arguments structure
mov [ebp-28],ecx; Counter of ARGS array [dynamic]
mov [ebp-20],esi; Current ARGS pointer [dynamic]

jmp MAIN.LOOP

; Return from call
; Restore prev. position of arguments array
; We skip it in special cases (e.g. called from 'D')
P.AT.RET:
cmp [ebp-266],bl
je P.AT.R.POP
add esp,4; Remove NULL pointer
mov [ebp-266],bl
Ret

P.AT.R.POP:
add esp,4; Remove NULL pointer
pop eax
mov [ebp-28],eax; Correct counter of arguments array [dynamic]
pop eax
mov [ebp-20],eax; Current position in arguments array

jmp MAIN.LOOP

; Save ARGS position/counter to VARS
P.AT.SAVE:

; We must save goto/call in order to determine if we need to skip or execute the following instructions
push eax

; Save pointer to NAME and END seq for later restore
push esi

; Compose variable
xor ax,ax
mov ax,'L'
xor cx,cx
mov cx,'='
Call COMPOSE.VARIABLE

; Set DATA
; DATA is:
;       +0 = [INT] Arguments size from current position
;       +4 = [POINTER] Current position in ARGS array
mov eax,[ebp-28]
mov [esi],eax
mov eax,[ebp-20]
mov [esi+4],eax

; Register variable
pop esi
Call MANAGE.VAR

; Do we need to skip instructions after /@?
; We do if it's '=' (procedure), we don't if it's '!' (goto)
pop eax
cmp ax,'='
jne MAIN.LOOP

; Skip all arguments until '#'
mov esi,[ebp-20]; Pointer: Arguments array
mov ecx,[ebp-28]; Counter: Rest of arguments array
xor ax,ax
mov al,'#'
Call FIND.ARGUMENT
test al,al
je EXIT

; Update current ARGS position and counter
mov [ebp-20],esi
mov [ebp-28],ecx

jmp MAIN.LOOP


; => '?' Perform a check upon variable <=
PROCESS.CHK:

; Split string
xor dh,dh
mov dl,','
Call SPLIT.STRING

Call GET.CHAR

; Check for special cases
cmp al,'?'; Operate on current error level
je P.C.EL
cmp al,'!'; Operate on Event
je P.C.EVENT

; Search for variable
push esi
Call GET.VARIABLE
test esi,esi
je P.C.RET.BAD

; Set up registers
mov edi,esi; Save pointer to data
mov edx,eax; Save type
pop esi

; Get comparison type
Call SKIP.NT.STRING; Skip variable's name
Call ACQUIRE.TWO.CHARS
Call SKIP.CHAR.FORWARD; ESI at NT, skip it

; Check type of variable
cmp dl,'N'; Numerical
je P.C.NUM
cmp dl,'T'; Text
je P.C.TXT
jmp P.C.RET.BAD; Unknown type

; Perform numerical comparison
P.C.NUM:
push eax; Save type
Call CONVERT.DECIMAL.STRING.TO.INTEGER
mov edx,eax; [INT] RHS
mov ecx,[edi]; [INT] LHS
pop eax; Type
Call PROCESS.NUMERICAL.COMPARISON
test al,al
jne P.C.RET.GOOD; True
jmp P.C.RET.BAD; False

; Perform text comparison
P.C.TXT:
xchg esi,edi; ESI = [POINTER] LHS Variable, EDI = [POINTER] RHS String
Call PROCESS.TEXT.COMPARISON
test al,al
jne P.C.RET.GOOD; True
jmp P.C.RET.BAD; False

; Check current error level
; Not yet implemented
P.C.EL:
jmp P.C.RET.BAD

; Check current event
; This event is set inside of /D procedure if we are in dispatch mode
P.C.EVENT:

; Skip '!' and set up vars
Call SKIP.NT.STRING
mov eax,[esi]; Key-char, e.g. 'D' for draw
mov ecx,[MBI.E.EVENT]

; Check if expected and current value match
; It's needed so we won't compare 'D' event against 'K' for example
cmp eax,ecx
jne P.C.RET.BAD

; See what kind of event we're processing
cmp ax,'D'; Draw - Instant match because there's no additional arguments
je P.C.RET.GOOD
cmp ax,'S'; Select - Instant match because there's no additional arguments
je P.C.RET.GOOD
cmp ax,'K'; Key event
je P.C.E.KEY
cmp ax,'M'; Mouse event
je P.C.E.MOUSE
jmp P.C.RET.BAD

; Key comparison
; We need to compare for for 'U/D' (up/down), then for actual key
P.C.E.KEY:

; Get 'U' or 'D' char in AX
; Set up pointer to READ structure
mov ecx,2
Call SKIP.CHARACTERS
Call ACQUIRE.TWO.CHARS
mov edi,[ebp-52]; Global read buffer
add edi,MAX_READ/2
add edi,C_WORD; Skip type ('KEY')

; Convert key definition to actual value
cmp ax,'U'
je P.C.E.K.U
cmp ax,'D'
je P.C.E.K.D
P.C.E.K.U:
xor ax,ax
jmp short P.C.E.K.CHECK
P.C.E.K.D:
mov ax,1

; Check for up/down event
P.C.E.K.CHECK:
cmp [edi],ax
jne P.C.RET.BAD
add edi,C_WORD; Skip to KEY value

; Check for KEY
Call PROCESS.COMPLEX.STRING
Call ACQUIRE.TWO.CHARS
cmp [edi],ax
jne P.C.RET.BAD
jmp short P.C.RET.GOOD

; Mouse comparison
P.C.E.MOUSE:

; Get 'D' or 'C' char in AX
; Set up pointer to READ
mov ecx,2
Call SKIP.CHARACTERS
Call ACQUIRE.TWO.CHARS
mov edi,[ebp-52]; Global read buffer
add edi,MAX_READ/2
add edi,C_WORD; Skip type ('MOUSE id')

; Check if click or double click event
cmp ax,'D'
je P.C.E.M.D
cmp ax,'C'
je P.C.E.M.C

; Compare double click
P.C.E.M.D:
cmp word [edi],3
je P.C.RET.GOOD
jmp short P.C.RET.BAD

; Compare click
P.C.E.M.C:
cmp word [edi],2
jne P.C.RET.BAD; Not a single click event

; Check for mouse button down
add edi,C_WORD; Skip to mouse button
Call CONVERT.DECIMAL.STRING.TO.INTEGER
cmp [edi],eax
jne P.C.RET.BAD
jmp short P.C.RET.GOOD

; Statement is TRUE - execute following instructions
P.C.RET.GOOD:
jmp MAIN.LOOP

; Statement is FALSE - Skip until /!
P.C.RET.BAD:

mov esi,[ebp-20]; Pointer: Arguments array
mov ecx,[ebp-28]; Counter: Rest of arguments array
xor ax,ax
mov al,'!'
Call FIND.ARGUMENT
test al,al
je EXIT

; Update current argument position
mov [ebp-20],esi
mov [ebp-28],ecx

jmp MAIN.LOOP


; => 'G' Set code page <=
PROCESS.G:

Call CONVERT.DECIMAL.STRING.TO.INTEGER

Call SET.OUTPUT.CP

jmp MAIN.LOOP


; => 'L' Draw line <=
; Structure examples:
;       /L S,[CHAR|ATTR],[CHAR|ATTR],... # Set drawing characters [START]
;       /L M,[CHAR|ATTR],[CHAR|ATTR],... # Set drawing characters [MIDDLE]
;       /L E,[CHAR|ATTR],[CHAR|ATTR],... # Set drawing characters [END]
;       /L C,20 # Draw line 20 chars long
;       /L L,5 # Draw 5 full lines (depends on DBOX)
;       /L F # Fill current DBOX
;       /L R # Reset LINES structure
PROCESS.L:

; Perform variable expanding
P.L.EXPAND:
mov al,[ebp-M_GLOBAL_EXPAND_VAR]; Pointer: 'L' mode: Expand
test al,al
je P.L.MODE; Skip
Call EXPAND.STR.VAR

; Test mode
P.L.MODE:
Call ACQUIRE.TWO.CHARS
cmp al,'S'
je P.L.SET.S
cmp al,'M'
je P.L.SET.M
cmp al,'E'
je P.L.SET.E
cmp al,'R'
je P.L.SET.RESET
cmp al,'C'
je P.L.CELLS
cmp al,'L'
je P.L.LINES
cmp al,'F'
je P.L.FILL
jmp MAIN.LOOP

; Set up start of the line
P.L.SET.S:
mov edi,[ebp-60]; MAX_LINE structure
jmp short P.L.SET.P

; Set up middle of the line
P.L.SET.M:
mov edi,[ebp-60]; MAX_LINE structure
mov ecx,LINE_OFFSET
Call SKIP.CHARACTERS.DST
jmp short P.L.SET.P

; Set up end of the line
P.L.SET.E:
mov edi,[ebp-60]; MAX_LINE structure
mov ecx,LINE_OFFSET
Call SKIP.CHARACTERS.DST
Call SKIP.CHARACTERS.DST

; Process complex string and copy to buffer
P.L.SET.P:
Call PROCESS.COMPLEX.STRING
Call COPY.NT.STR
mov edi,eax; EAX: From COPY.NT.STR: Start of copied string
mov ecx,LINE_OFFSET-1
Call SKIP.CHARACTERS.DST
mov [edi],bx; Place NT
jmp MAIN.LOOP

; Reset start, middle and end of the line to default
P.L.SET.RESET:

; We simply fill the whole structure with zeros
mov edi,[ebp-60]
mov ax,bx
mov ecx,LINE_OFFSET*3
Call FILL.CHARS

jmp MAIN.LOOP

; Prepare line (cells long)
P.L.CELLS:

push edi; We'll draw here later so save it

; Prepare line in memory
Call CONVERT.DECIMAL.STRING.TO.INTEGER
mov ecx,eax
mov edi,[esp]; Pointer: DATA where line will be expanded
push ecx; Save size of line
Call PREPARE.LINE
pop ecx; Restore size of line
jmp short P.L.DRAW

; Prepare line (lines long)
P.L.LINES:

; Get size of the line
Call CONVERT.DECIMAL.STRING.TO.INTEGER

; Other procedures may call this directly if they want to draw a line
P.L.LINES.ACTION:

; ESI points after control structure. Save it because we're going to draw here later
push esi
mov ecx,eax

; Prepare line counter
mov edx,[ebp-82]; [POINTER] DBOX
xor eax,eax
mov ax,[edx+2]; X [right]
inc ax; +1 because inclusive: 0..2 = 3 chars
sub ax,[edx]; X [left]
mov [ebp-536],eax; Line counter: Save it for P.L.L.LOOP
mov [ebp-532],ebx; There will be resulting counter: LINE x UserInput

; Prepare line in memory
mov eax,P.L.L.LOOP; Callback
mov edi,[esp]; Pointer: DATA where line will be expanded
Call LOOP.TIMES
mov ecx,[ebp-532]; Resulting counter
jmp short P.L.DRAW

; Expand the line needed amount of times
P.L.L.LOOP:

mov ecx,[ebp-536]; Line counter
add dword [ebp-532],ecx
Call PREPARE.LINE
mov al,1; Continue execution

Ret

; Draw using text or attributes
P.L.DRAW:

; Restore pointer to DATA where line was expanded
pop esi

; Cancel drawing on screen and return if flag is set
cmp [ebp-267],bl
je P.L.D.CONTINUE
; OUT:
;       ESI = Pointer: Start of expanded line
;       EDI = Pointer: End of expanded line
Ret

; Draw using characters or attributes
P.L.D.CONTINUE:
mov al,[ebp-M_L_DRAW_USING]
cmp al,'A'
je P.L.D.ATTR; Attributes
jmp PROCESS.T; Chars

; Draw attributes
P.L.D.ATTR:

mov [ebp-M_GLOBAL_CURSOR],al; Cursor will operate on internal position
Call PROCESS.A.WRITE
mov [ebp-M_GLOBAL_CURSOR],bl; Restore normal cursor operation

jmp MAIN.LOOP

; Fill the whole DBOX
P.L.FILL:

; Get size of a row in ECX
mov edx,[ebp-82]; Pointer: DBOX
xor ecx,ecx
mov cx,[edx+2]; X [right]
sub cx,[edx]
inc cx

; Get size of a column in EAX
xor eax,eax
mov ax,[edx+6]; Y [bottom]
sub ax,[edx+4]; Y [top]
inc ax

; Multiply to get total counter of cells
Call MULTIPLY.INTEGER

; Prepare and draw line
push edi; We'll draw here in P.L.DRAW
mov ecx,eax
push ecx; Save size of line
Call PREPARE.LINE
pop ecx; Restore size of line
jmp short P.L.DRAW


; => 'M' Modify internal logic <=
PROCESS.M:

Call ACQUIRE.CHAR; AX = Mode

; Compare what procedure to modify
mov edi,ebp; We subtract from it later to get a proper pointer in EBP
cmp al,'T'
je P.M.T.MODE
cmp al,'L'
je P.M.L.MODE
cmp al,'A'
je P.M.A.MODE
cmp al,'P'
je P.M.P.MODE
cmp al,'#'; # Stands for GLOBAL mode
je P.M.G.MODE
cmp al,'+'; # Save mode to VARS
je P.M.SAVE
cmp al,'='; # Restore mode from VARS
je P.M.RESTORE
cmp al,'!'; # Reset all flags
je P.M.RESET
jmp MAIN.LOOP

; Save current mode to VARS array
P.M.SAVE:

; Save pointer to start of variable for future restore
push esi

; Compose variable
xor ax,ax
mov ax,'M'
xor cx,cx
mov cx,'='
Call COMPOSE.VARIABLE

; Move all flags into DATA section (pointer in ESI)
mov edi,esi
mov esi,ebp
sub esi,M_GLOBAL_BASE+1
mov ecx,M_SIZE
Call COPY.MEM.GENERAL

; Register variable
pop esi
Call MANAGE.VAR

jmp MAIN.LOOP

; Restore mode from VARS array
P.M.RESTORE:

; Try to get a previously saved mode
Call GET.MODE.VARIABLE
test esi,esi
je EXIT

; Override current flags from VARS array
mov edi,ebp
sub edi,M_GLOBAL_BASE+1
mov ecx,M_SIZE/2
Call COPY.MEM.WORDS

jmp MAIN.LOOP

; Reset flags to default state
P.M.RESET:

; All flags to zero
mov edi,ebp
sub edi,M_GLOBAL_BASE+1
mov ecx,M_SIZE/2
mov ax,bx
Call FILL.WORDS

jmp MAIN.LOOP

; 'T' procedure
P.M.T.MODE:
sub edi,M_T_BASE; EDI = Pointer: 'T' modes
jmp short P.M.SET.MODE

; 'L' procedure
P.M.L.MODE:
sub edi,M_L_BASE; EDI = Pointer: 'L' modes
jmp short P.M.SET.MODE

; 'A' procedure
P.M.A.MODE:
sub edi,M_A_BASE; EDI = Pointer: 'A' modes
jmp short P.M.SET.MODE

; 'P' procedure
P.M.P.MODE:
sub edi,M_P_BASE; EDI = Pointer: 'P' modes
jmp short P.M.SET.MODE

; 'GLOBAL' procedure
P.M.G.MODE:
sub edi,M_GLOBAL_BASE; EDI = Pointer: GLOBAL modes

; Set mode
P.M.SET.MODE:
Call SKIP.CHAR.FORWARD; Skip ':' separator

; Setup callback and loop over chars
mov eax,P.M.S.M.LOOP
Call LOOP.OVER.CHARS.NT

jmp MAIN.LOOP

; Loop over modes
P.M.S.M.LOOP:
cmp al,'-'; Do not modify
je P.M.RET
cmp al,'.'; Reset to default
je P.M.RET.DEFAULT

mov [edi],al; Set new mode
jmp short P.M.RET

; Reset current mode to default
P.M.RET.DEFAULT:
mov [edi],bl

; Do not touch current mode
P.M.RET:
dec edi; Next mode
Ret


; => 'A' Output attributes <=
PROCESS.A:

; Expand variable if set
mov al,[ebp-M_GLOBAL_EXPAND_VAR]; Pointer: 'A' mode: Expand variable
test al,al
je P.A.SPLIT
Call EXPAND.STR.VAR

; Split attributes string
P.A.SPLIT:
xor dh,dh
mov dl,','
Call SPLIT.STRING

; Convert string array to binary word numbers
Call CONVERT.STR.ARRAY.TO.WORD
xchg esi,edi

; Write to console
PROCESS.A.WRITE:
Call WRITE.CONSOLE.ATTRIBUTES

; Update cursor position and return
P.A.END:
;Call UPDATE.INTERNAL.CURSOR.POS
jmp MAIN.LOOP


; => 'B' Correct DBOX structure <=
PROCESS.B:

; Check mode
Call ACQUIRE.CHAR
Call SKIP.CHAR.FORWARD
cmp al,'S'; Select DBOX
je P.B.SELECT
cmp al,'A'; Add new DBOX
je P.B.ADD
cmp al,'C'; Change currently selected DBOX
je P.B.CHANGE
cmp al,'R'; Reset DBOX
je P.B.RESET
cmp al,'#'; Set mouse position to start of current DBOX
je P.B.SET.CURSOR
jmp MAIN.LOOP

; Select DBOX
P.B.SELECT:

; Check for default case first
Call GET.CHAR
cmp al,'-'
jne P.B.S.VAR

; Reset pointer to default DBOX
mov eax,[ebp-78]
mov [ebp-82],eax

jmp MAIN.LOOP

; Try to find user specified DBOX, exit on fail
P.B.S.VAR:
Call GET.DBOX.VARIABLE
cmp al,1
jne EXIT

; Set DBOX to new pointer
mov [ebp-82],esi

jmp MAIN.LOOP

; Add new DBOX
P.B.ADD:

push esi

; Split string
xor dh,dh
mov dl,','
Call SPLIT.STRING

; First we need to get numeric values for our new DBOX
; We skip name in ESI and get to the values, EDI+128 is to make room for converted numbers
Call SKIP.NT.STRING
mov edi,esi
add edi,UTF_CHAR_SIZE*128
push edi

; Pointers are set up, let's convert
; We must process 4 members of DBOX structure
mov eax,P.B.A.CONVERT
mov ecx,4
Call LOOP.TIMES

; Restore original pointers
; EDI = Start of converted numbers
; ESI = Name of new DBOX
pop edi
mov esi,[esp]

; Compose variable
xor ax,ax
mov ax,'D'
xor cx,cx
mov cx,'='
Call COMPOSE.VARIABLE

; Copy DBOX values
xchg esi,edi
mov ecx,4
Call COPY.MEM.WORDS

; Register variable
pop esi
Call MANAGE.VAR

jmp MAIN.LOOP

; CALLBACK: Convert each member to binary number
P.B.A.CONVERT:

Call CONVERT.DECIMAL.STRING.TO.INTEGER
mov [edi],eax
add edi,2

mov al,1

Ret

; Change currently selected DBOX
P.B.CHANGE:

; Split string
xor dh,dh
mov dl,','
Call SPLIT.STRING

; Set up initial counter. We perform +2 to this after each P.B.C.CONVERT callback as we move through DBOX structure
sub esp,4
mov [esp],ebx

; DBOX is 4 WORDS in size
mov eax,P.B.C.CONVERT
mov ecx,4
Call LOOP.TIMES

; Remove temp counter
add esp,4

jmp MAIN.LOOP

; CALLBACK: Convert each member to binary number
P.B.C.CONVERT:

; Get mode for CALCULATE.SIMPLE
Call ACQUIRE.CHAR
push eax

; Get RHS number
Call CONVERT.DECIMAL.STRING.TO.INTEGER
mov edx,eax

; Get LHS number
mov edi,[ebp-82]
add edi,[esp+20]
xor ecx,ecx
mov cx,[edi]

; Process calculation and save result
pop eax
Call CALCULATE.SIMPLE
mov [edi],ax
add dword [esp+16],2

mov al,1

Ret

; Reset currently selected DBOX
P.B.RESET:

Call RESET.DBOX

jmp MAIN.LOOP

; Set cursor position to start of current DBOX
P.B.SET.CURSOR:

; Select current DBOX and setup COORD structure
mov edx,[ebp-82]
mov ax,[edx+4]; Y top
shl eax,16; Y to high part
mov ax,[edx]; X left

Call SET.CURSOR.POS

jmp MAIN.LOOP


; => 'V' Change cursor's size/visibility <=
PROCESS.V:

; Check mode
Call ACQUIRE.TWO.CHARS
cmp al,'V'
je P.V.VIS
cmp al,'S'
je P.V.SIZE
jmp MAIN.LOOP

; Change visibility
P.V.VIS:
Call CONVERT.DECIMAL.STRING.TO.INTEGER
mov [CSV.V],eax
jmp short P.V.SET

; Change size
P.V.SIZE:
Call CONVERT.DECIMAL.STRING.TO.INTEGER
mov [CSV.S],eax

; Apply settings
P.V.SET:
Call SET.CURSOR.SIZE.AND.VISIBILITY
jmp MAIN.LOOP


; => 'b' Manage console buffer <=
PROCESS.BB:

; Check mode
Call ACQUIRE.TWO.CHARS
cmp al,'C'
je P.BB.CRT; Create new buffer
cmp al,'~'
je P.BB.SW; Switch buffers
cmp al,'Y'
je P.BB.COPY; Copy background to active
jmp MAIN.LOOP

; Create background buffer
P.BB.CRT:

cmp [ebp-300],ebx
jne MAIN.LOOP; Buffer is already created

; Create buffer and save handle
Call CREATE.CONSOLE.BUFFER
mov [ebp-300],eax

jmp MAIN.LOOP

; Switch buffers
P.BB.SW:

mov eax,[ebp-300]; Previously created buffer
cmp [ebp-118],eax; Current buffer = created buffer?
je P.BB.SW.OR; Set original

; Set new buffer as default
mov [ebp-118],eax
jmp MAIN.LOOP

; Restore original buffer
P.BB.SW.OR:

mov eax,[HND.STD.OUT]; Original out buffer
mov [ebp-118],eax; Set as default

jmp MAIN.LOOP

; Copy from shadow buffer to active buffer
P.BB.COPY:

Call COPY.FROM.SHADOW.BUFFER

jmp MAIN.LOOP


; => 'm' Manage program memory <=
PROCESS.MM:

; Check mode
Call ACQUIRE.TWO.CHARS
cmp al,'A'
je P.MM.ARG; Create new buffer for arguments
cmp al,'D'
je P.MM.DATA; Create new buffer for data
jmp MAIN.LOOP

; Redefine ARGS buffer
P.MM.ARG:
Call CONVERT.DECIMAL.STRING.TO.INTEGER
Call ALLOCATE.MEMORY

; Transfer old arguments to a new place
mov ecx,[ebp-8]; Counter of arguments array
mov edi,eax; Where to transfer old arguments
mov esi,[ebp-48]; Pointer to start of arguments
Call COPY.MEM.WORDS
mov [edi],ebx; Clear trash at the end

; Set up pointers
mov ecx,[ebp-20]; Current position in old arguments array
mov edx,[ebp-48]; Start of old arguments
sub ecx,edx; Difference
mov [ebp-48],eax; New static pointer of arguments
add eax,ecx; Make a proper shift in the new array
mov [ebp-20],eax; New dynamic pointer of arguments

jmp MAIN.LOOP

; Redefine data buffer
; Not much is needed here compared to P.MM.ARG
; We just allocate new buffer and correct pointer to DATA
P.MM.DATA:

Call CONVERT.DECIMAL.STRING.TO.INTEGER
Call ALLOCATE.MEMORY

mov [ebp-24],eax

jmp MAIN.LOOP


; => 'R' Read console input <=
PROCESS.R:

; Create event for sync. between read and timeout threads
Call CREATE.EVENT
mov [READ.EVENT],eax

; Create simple thread for console reading
mov eax,THREAD.READ
mov ecx,esi
Call CREATE.THREAD.SIMPLE
mov [READ.THREAD],eax

; Wait until thread's done
; After this we have user's input in EBP-52
mov ecx,INFINITE
Call WAIT.FOR.OBJECT

; Close handles
mov eax,[READ.EVENT]
Call CLOSE.HANDLE
mov eax,[READ.THREAD]
Call CLOSE.HANDLE

jmp MAIN.LOOP


; => 'W' Write to console/file/etc. <=
PROCESS.W:

; Get source to write from
Call ACQUIRE.CHAR
Call SKIP.CHAR.FORWARD

cmp ax,'R'
je P.W.WRITE.READ.BUFFER
;cmp ax,'D'
;je P.W.WRITE.DATA.BUFFER

jmp MAIN.LOOP

; Set source from read buffer
P.W.WRITE.READ.BUFFER:
mov edi,[ebp-52]
;jmp short P.W.WRITE.BUFFER

; Get method to write
P.W.WRITE.METHOD:
Call ACQUIRE.CHAR
Call SKIP.CHAR.FORWARD
xchg esi,edi

; Check what procedure to use
cmp ax,'G'
je P.W.WRITE.GENERAL
cmp ax,'R'
je P.W.WRITE.RAW

; Write using general procedure
P.W.WRITE.GENERAL:
Call PROCESS.T
jmp MAIN.LOOP

; Write raw data to handle
P.W.WRITE.RAW:
Call COUNT.STRING
Call WRITE.TO.FILE
jmp MAIN.LOOP


; => 'F' Manage frames <=
PROCESS.F:

; Flag for P.F.DBOX.INSIDE: jmp or return, by default do not return
mov [ebp-265],bl

; Get KEY word
Call ACQUIRE.CHAR
Call SKIP.CHAR.FORWARD

; Compare mode
cmp ax,'R'
je P.F.REGISTER
cmp ax,'I'
je P.F.DBOX.INSIDE
cmp ax,'O'
je P.F.DBOX.OUTSIDE
jmp EXIT; Unknown action

; Register frame
P.F.REGISTER:

push esi

; Process complex string and skip to the end of NT string (EDI)
; We'll copy frame definitions there
Call PROCESS.COMPLEX.STRING
Call SKIP.NT.STRING
mov edi,esi
mov esi,[esp]

; Split string
xor dh,dh
mov dl,','
Call SPLIT.STRING

; Make room for variable definition
push edi; Start of new data
Call SKIP.NT.STRING
mov ecx,edi
sub ecx,esi
Call COPY.MEM.GENERAL

; Compose variable
mov esi,[esp+4]
xor ax,ax
mov ax,'F'
xor cx,cx
mov cx,'='
Call COMPOSE.VARIABLE

; Adjust frame values to beginning of variable structure
mov eax,edi; EAX = End of data
pop edi; EDI = Start of data
mov ecx,edi
sub ecx,esi; ECX = Difference between original data and new
Call COLLAPSE.MEMORY.BYTES

; Register variable
pop esi
Call MANAGE.VAR

jmp MAIN.LOOP

; Draw INSIDE DBOX
P.F.DBOX.INSIDE:

; Get pointer to our structure
; EDI = Pointer to frame values
push esi
Call GET.VARIABLE
test esi,esi
je EXIT
mov edi,esi
pop esi

; Save and switch SRC and DST, we're going to use:
; ESI = Pointer: Frame values
; EDI = Pointer: Arguments for 'L' procedure
xchg esi,edi
push edi; Save start of the line

; Compose and draw starting line
; We save EAX because it points right after expanded line
Call PREPARE.FRAME.LINE
mov eax,1
Call DRAW.FRAME.LINE

; Compose and draw middle line
Call PREPARE.FRAME.LINE

; Here we must calculate the needed size: TOTAL-2 lines at start and end
xor eax,eax
xor edx,edx
mov ecx,[ebp-82]; DBOX
mov dx,[ecx+4]; BOTTOM
mov ax,[ecx+6]; TOP
sub eax,edx; Total by Y
dec eax; Because inclusive
je P.F.D.I.END; ZERO = No room for middle
js P.F.D.I.RET; SIGN = No room even for the end line

; Draw middle lines
Call DRAW.FRAME.LINE

; Compose and draw ending line
P.F.D.I.END:
Call PREPARE.FRAME.LINE
mov eax,1
Call DRAW.FRAME.LINE

; Draw ending line
pop esi
Call P.L.D.CONTINUE

; Jump or return
; This can be used as procedure for P.F.DBOX.OUTSIDE
P.F.D.I.RET:
cmp [ebp-265],bl
je MAIN.LOOP

Ret

; Draw OUTSIDE DBOX
; We just change DBOX size and then call P.F.DBOX.INSIDE
P.F.DBOX.OUTSIDE:

; Increase/decrease each member of DBOX structure
mov eax,[ebp-82]; DBOX
dec word [eax]; X left
inc word [eax+2]; X right
dec word [eax+4]; Y Top
inc word [eax+6]; Y Bottom

; Process everything else
mov [ebp-265],al
Call P.F.DBOX.INSIDE

; Restore original DBOX structure
mov eax,[ebp-82]; DBOX
inc word [eax]; X left
dec word [eax+2]; X right
inc word [eax+4]; Y Top
dec word [eax+6]; Y Bottom

jmp MAIN.LOOP


; => 'E' Manage active elements <=
PROCESS.E:

; Get KEY word
Call ACQUIRE.CHAR
Call SKIP.CHAR.FORWARD

; Compare mode
cmp ax,'R'
je P.E.REGISTER
jmp EXIT; Unknown action

; Register active element
P.E.REGISTER:

push esi

; First we need to get numeric values for our new DBOX
; We skip name in ESI and get to the values, EDI+128 is to make room for converted numbers
Call SKIP.NT.STRING
mov edi,esi
add edi,UTF_CHAR_SIZE*128
push edi

; Split string and skip to the DBOX definition
mov esi,[esp+4]
xor dh,dh
mov dl,','
Call SPLIT.STRING
Call SKIP.NT.STRING

; Pointers are set up, let's convert
; We must process 4 members of DBOX structure
; We reuse the same procedure as in 'B' argument
mov eax,P.B.A.CONVERT
mov ecx,4
Call LOOP.TIMES

; Copy procedure after DBOX definition
Call COPY.NT.STR

; Restore original pointers
; EDI = End of converted numbers+procedure
; ESI = Name of new DBOX
push edi
mov esi,[esp+8]

; Compose variable
xor ax,ax
mov ax,'E'
xor cx,cx
mov cx,'='
Call COMPOSE.VARIABLE

; Adjust procedure to beginning of variable structure
pop eax; EAX = End of DBOX+PROCEDURE
pop edi; EDI = Start of DBOX+PROCEDURE
mov ecx,edi
sub ecx,esi; ECX = Difference between original data and new
Call COLLAPSE.MEMORY.BYTES
xchg esi,eax
Call ADD.NULL.TERMINATOR

; Register variable
pop esi
Call MANAGE.VAR
mov [MBI.E.SELECTED],edi

jmp MAIN.LOOP


; => 'D' Read and dispatch messages for active elements <=
PROCESS.D:

; Get KEY word
Call ACQUIRE.CHAR
Call SKIP.CHAR.FORWARD

; Compare mode
cmp ax,'R'
je P.D.REGISTER; Register navigational buttons
cmp ax,'D'
je P.D.DISPATCH; Enter loop
jmp EXIT; Unknown action

; Register navigational buttons (not yet implemented)
P.D.REGISTER:

jmp MAIN.LOOP

; Enter dispatch loop
P.D.DISPATCH:

; Draw every registered active element
Call DRAW.ACTIVE.ELEMENTS

; Set element's DBOX
mov esi,[MBI.E.SELECTED]
mov [ebp-82],esi

; Set up event for active element, S = Select
xor eax,eax
mov ax,'S'
mov [MBI.E.EVENT],eax

; Update currently selected element
mov [ebp-266],al
add esi,8; DBOX structure is 8 bytes
Call P.AT.CALL

; DISPATCH LOOP
; Event is returned in EDI
P.D.D.LOOP:
Call READ.ANY

; Check if we got a KEY or a MOUSE event
mov ax,[edi]
add edi,C_WORD
cmp ax,1
je P.D.D.L.KEY
cmp ax,2
je P.D.D.L.MOUSE
jmp short P.D.D.LOOP; Unknown event

; Process KEY event
P.D.D.L.KEY:

; Skip key UP or DOWN
add edi,C_WORD

; Check for navigational buttons
mov ax,[edi]
cmp ax,[MBI.N.LEFT]
je P.D.D.L.K.LEFT
cmp ax,[MBI.N.RIGHT]
je P.D.D.L.K.RIGHT
cmp ax,[MBI.N.UP]
je P.D.D.L.K.UP
cmp ax,[MBI.N.DOWN]
je P.D.D.L.K.DOWN

; Pass down key event to selected element
; Set element's DBOX
mov esi,[MBI.E.SELECTED]
mov [ebp-82],esi

; Set up event for active elements, K = Key
xor eax,eax
mov ax,'K'
mov [MBI.E.EVENT],eax

; Call label
mov [ebp-266],al
add esi,8; DBOX structure is 8 bytes
Call P.AT.CALL

jmp short P.D.D.LOOP

; Set up what element we're searching for (relative to what side?)
P.D.D.L.K.LEFT:
mov ax,'L'
mov dx,'B'
jmp short P.D.D.L.FIND
P.D.D.L.K.RIGHT:
mov ax,'R'
mov dx,'F'
jmp short P.D.D.L.FIND
P.D.D.L.K.UP:
mov ax,'U'
mov dx,'B'
jmp short P.D.D.L.FIND
P.D.D.L.K.DOWN:
mov ax,'D'
mov dx,'F'

; Only trigger if key is down
P.D.D.L.FIND:
cmp word [edi-C_WORD],bx
je P.D.D.LOOP

; Find a relative element to our current position
Call OBTAIN.ACTIVE.ELEMENT.RELATIVE
test al,al
je P.D.D.LOOP; Didn't find the element
jmp short P.D.D.L.SELECT

; Process mouse event
P.D.D.L.MOUSE:

; Check for mouse navigation (MOVED event)
cmp word [edi],1
je P.D.D.L.M.NAV

; Pass mouse event down to selected element
; Set element's DBOX
mov esi,[MBI.E.SELECTED]
mov [ebp-82],esi

; Set up event for active element, M = Mouse
xor eax,eax
mov ax,'M'
mov [MBI.E.EVENT],eax

; Call label
mov [ebp-266],al
add esi,8; DBOX structure is 8 bytes
Call P.AT.CALL

jmp P.D.D.LOOP

; Navigation using mouse
P.D.D.L.M.NAV:

; Get COORD structure and find element
mov eax,[edi+6]
Call OBTAIN.ACTIVE.ELEMENT.ABSOLUTE
test al,al
je P.D.D.LOOP; Didn't find the element

; Optimization: Don't call the same procedure over and over
; if it were already called. In this case, current and previous element will be the same
cmp esi,edx
je P.D.D.LOOP

; Select next element
P.D.D.L.SELECT:

; We need to DEACTIVATE the previously selected element first
; OBTAIN.ACTIVE.ELEMENT.* returns it in EDX
test edx,edx
je P.D.D.L.S.ACT; No previously selected element

; Set DBOX to new pointer
mov [ebp-82],edx

; Set up event for active elements, D = Draw
; I think there's no need for special event for deselect
xor eax,eax
mov ax,'D'
mov [MBI.E.EVENT],eax

; Call previous label
push esi; Save currently selected label
mov esi,edx
mov [ebp-266],al
add esi,8; DBOX structure is 8 bytes
Call P.AT.CALL
pop esi

; Call currently selected element
P.D.D.L.S.ACT:

; Set DBOX to new pointer
mov [ebp-82],esi

; Set up event for active elements, S = Select
xor eax,eax
mov ax,'S'
mov [MBI.E.EVENT],eax

; Call label
mov [ebp-266],al
add esi,8; DBOX structure is 8 bytes
Call P.AT.CALL

jmp P.D.D.LOOP


; => 'x' Execute xci script <=
PROCESS.XX:

; Open file and exit if unsuccessful
Call OPEN.FILE.FOR.READING
test eax,eax
je EXIT

; Get file size (file handle and size on stack)
push eax
Call GET.FILE.SIZE
push eax

; Allocate memory to hold file's data.
; Pointer to newly allocated memory in EDI
Call ALLOCATE.MEMORY
mov edi,eax

; Read file into our buffer
mov ecx,[esp]; Size
mov eax,[esp+4]; Handle
Call READ.FROM.HANDLE

; Zero end the buffer
pop ecx
sub ecx,BASIC_REGISTER
mov [edi+ecx],ebx

; Make a bigger buffer for converted data
; We simply multiply it by BASIC_REGISTER because who treasure RAM these days
mov eax,UTF_CHAR_SIZE
Call MULTIPLY.INTEGER
add eax,BASIC_REGISTER
mov [ebp-16],eax

; Allocate memory to hold a converted UTF-16 array
; Pointer to newly allocated memory in ESI
Call ALLOCATE.MEMORY
mov esi,eax

; Convert to multi byte (UTF-16)
; We exit if user didn't specify code page; ECX is a number of Unicode characters
cmp [ebp-M_P_CONVERT],bl
je EXIT
xchg esi,edi
mov al,[ebp-M_P_CONVERT]
Call CONVERT.BYTES.TO.WIDECHAR
mov dword [ebp-16],MAX_BUFFER
push ecx

; Free old memory
mov [ebp-32],esi
Call FREE.MEMORY

; Replace CRLF with NULL
mov ecx,[esp]
xchg esi,edi
xor ax,ax
mov dx,0xD
Call REPLACE.CHAR.GLOBAL
mov ecx,[esp]
xor ax,ax
mov dx,0xA
Call REPLACE.CHAR.GLOBAL

; Prepare arguments by removing '/' symbol and process exclude characters
pop ecx
mov [ebp-8],ecx; Save counter of arguments array: Static
mov [ebp-28],ecx; Save counter of arguments array: Dynamic
Call PREPARE.ARGUMENTS
mov [ebp-20],esi; Pointer: Start of arguments

; Close the file
pop eax
Call CLOSE.HANDLE

jmp MAIN.LOOP


; => 'P' Get arguments from pipe <=
PROCESS.P:

cmp [ebp-304],ebx
jne P.P.READ; Pipe is already created

; Create pipe
Call CREATE.PIPE
mov [ebp-304],eax; Pipe handle

jmp MAIN.LOOP

; Read from pipe
P.P.READ:

mov eax,[ebp-304]; Pipe handle
mov edi,[ebp-24]; EDI = Pointer: DATA buffer
Call READ.FROM.PIPE
test eax,eax
je EXIT; Couldn't read

; Convert to multi byte
cmp [ebp-M_P_CONVERT],bl
je P.P.COPY; Skip conversion
xchg esi,edi
mov al,[ebp-M_P_CONVERT]
Call CONVERT.BYTES.TO.WIDECHAR

; Copy arguments
P.P.COPY:
mov esi,edi
mov edi,[ebp-48]; Pointer: Start of arguments
Call COPY.ARGS; Copy arguments from ESI to EDI
test eax,eax
je EXIT; Couldn't copy

; Setup pointer to arguments and data buffers
mov [ebp-8],ecx; Save counter of arguments array: Static
mov [ebp-28],ecx; Save counter of arguments array: Dynamic
mov esi,eax; ESI = Pointer: Buffer with copied arguments
Call PREPARE.ARGUMENTS
mov [ebp-20],esi; Pointer: Start of arguments

jmp MAIN.LOOP


; => 'Q' Set error code and exit <=
PROCESS.Q:

cmp [esi],bx
je EXIT; No exit code specified

Call CONVERT.DECIMAL.STRING.TO.INTEGER
mov [CODE.EXIT],eax; User's exit code

jmp short EXIT


; >>>=== END OF UPPER LOGIC ===<<<
; Exit if we don't currently listen to a pipe
EXIT.IF.NOT.PIPE:
cmp [ebp-304],ebx
jne PROCESS.P; Pipe is active

; Exit thread or process
EXIT:
cmp [ebp-260],ebx
je E.PROCESS; Exit process
Call EXIT.THREAD

; Exit process
E.PROCESS:
Call EXIT.PROCESS


; >>>=== GENERAL PROCEDURES ===<<<
%include 'P-Loops.asm'; LOOP.OVER procedures
%include 'P-Vars.asm'; Variables-related procedures
%include 'P-System.asm'; System-related procedures
%include 'P-Memory.asm'; Memory management
%include 'P-Console.asm'; Console functions
%include 'P-Cursor.asm'; Cursor management
%include 'P-Text.asm'; Text management
%include 'P-Numbers.asm'; Numbers management
%include 'P-Specific.asm'; Specific functions
%include 'P-Threads.asm'; Additional threads


; >>>=== PROCEDURES SPECIFIC TO MAIN MODULE ===<<<
; >>>=== 'L' Line drawing supportive procedures ===<<<
; => Prepare a line in memory <=
; IN:
;       ECX = [INT] Size of line
;       EDI = [POINTER] Draw where
; OUT:
;       EDI = [POINTER] After last drawn character
PREPARE.LINE:

push ecx; Save total line counter

; Draw start of the line
mov [edi],bx; Remove trash
mov esi,[ebp-60]; Line structure
Call COUNT.STRING.UTF16
test ecx,ecx
je P.L.DRAW.M; Data not specified - skip

; Correct and check total line counter
sub [esp],ecx; Correct counter
jl P.L.END; No space to draw a line - abort

; Expand start
mov eax,ecx; It's the same because START needed to be expanded only one time
Call EXPAND.WORDS.LOOPED
test al,al
je P.L.END

; Draw middle of line
P.L.DRAW.M:

; Skip to middle and count MIDDLE data
mov esi,[ebp-60]; Line structure
mov ecx,LINE_OFFSET
Call SKIP.CHARACTERS
Call COUNT.STRING.UTF16
test ecx,ecx
je P.L.DRAW.E; Data not specified - skip

; Correct and check total line counter
mov eax,ecx; Size of expanding structure
mov ecx,[esp]; Total size to expand
sub [esp],eax; Correct counter, we have to draw END one time
jl P.L.END; No space to draw a line - abort

; Expand middle until counter != 0
Call EXPAND.WORDS.LOOPED
test al,al
je P.L.END

; Draw end of line
P.L.DRAW.E:

; Skip to end and count END data
mov esi,[ebp-60]; Line structure
mov ecx,LINE_OFFSET*2
Call SKIP.CHARACTERS
Call COUNT.STRING.UTF16
test ecx,ecx
je P.L.END; Data not specified - skip

; Back off a little because we drew too much in P.L.DRAW.M
Call SKIP.CHARACTERS.BACKWARDS.DST
mov eax,ecx
Call EXPAND.WORDS.LOOPED

; Finalizing
P.L.END:
mov [edi],ebx; Remove potential trash
add esp,4; Remove local variable

Ret


; >>>=== 'F' frame supportive procedures ===<<<
; => Prepare START-MIDDLE-END of the line for 'L' <=
; I need to rewrite this, it's clumsy.
; IN:
;       ESI = Pointer: Frame structure
;       EDI = Pointer: Where to construct argument
; OUT:
;       ESI = Pointer: Next three elements in frame structure
PREPARE.FRAME.LINE:

push esi
push edi

; Compose /L:S,
xor ah,ah
mov al,'S'
Call REGISTER.ARGUMENT.AND.DATA
mov [esp+4],esi

; Call /L procedure
mov esi,[esp]
Call PROCESS.L

; Compose /L:M,
mov esi,[esp+4]
mov edi,[esp]
xor ah,ah
mov al,'M'
Call REGISTER.ARGUMENT.AND.DATA
mov [esp+4],esi

; Call /L procedure
mov esi,[esp]
Call PROCESS.L

; Compose /L:E,
mov esi,[esp+4]
mov edi,[esp]
xor ah,ah
mov al,'E'
Call REGISTER.ARGUMENT.AND.DATA
mov [esp+4],esi

; Call /L procedure
mov esi,[esp]
Call PROCESS.L

; Finalize
pop edi
pop esi
Ret


; => Draw part of the frame <=
; IN:
;       EAX = Counter: How many lines to draw
;       EDI = Pointer: Place to construct line
; OUT:
;       EDI = Pointer: End of expanded line
DRAW.FRAME.LINE:

push esi

; Call /L procedure
; It won't draw anything, just expand line and return (see flag 267)
mov [ebp-267],al
mov esi,edi
Call P.L.LINES.ACTION
mov [ebp-267],bl

pop esi

Ret
