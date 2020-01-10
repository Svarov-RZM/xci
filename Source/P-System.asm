; P-System.asm
;
; Copyright (c) 2019, Dmitry Razumovsky (Svarov-RZM)
; You may distribute under the terms of BSD 2-Clause License
; as specified in the LICENSE.TXT file.
;
; >>>=== SYSTEM PROCEDURES ===<<<
; => Close system handle <=
; IN:
;       EAX = [HANDLE]
CLOSE.HANDLE:

push eax;1
Call [CloseHandle];:1

Ret


; => Create event <=
; OUT:
;       EAX = [HANDLE] Event
CREATE.EVENT:

; Call API
push ebx;4; No name for event
push ebx;3; Non-signaled state
push 1;2; Manual reset event
push ebx;1; Security descriptor
Call [CreateEventW];:4

Ret


; => Create/open file <=
; IN:
;       EAX = [INT] Mode: Desired access
;       ECX = [INT] Mode: Creation disposition
;       EDX = [INT] Mode: Flags and attributes
;       ESI = [POINTER] Path to file
; OUT:
;       EAX = [HANDLE] File
CREATE.FILE:

; Call API
push ebx;7; hTemplateFile
push edx;6; dwFlagsAndAttributes
push ecx;5; dwCreationDisposition
push ebx;4; lpSecurityAttributes
push ebx;3; dwShareMode
push eax;2; dwDesiredAccess
push esi;1; lpFileName
Call [CreateFileW];:7

Ret


; => Create pipe <=
; Note: Hard-coded values for buffers. Needs re-working.
; IN:
;       ESI = [POINTER] Pipe path like \\.\pipe\xci
; OUT:
;       EAX = [HANDLE] Pipe
CREATE.PIPE:

; Call API
push ebx;8; SA
push ebx;7; default wait
push dword 8192;6; In buffer
push dword 8192;5; Out buffer
push 1;4; One instant
push PIPE_TYPE_BYTE+PIPE_WAIT;3
push PIPE_ACCESS_DUPLEX;2; dwOpenMode
push esi;1; Pipe name
Call [CreateNamedPipeW];:8

Ret


; => Create simple thread <=
; IN:
;       EAX = [POINTER] Thread procedure
;       ECX = [BASIC_REGISTER] Optional argument
; OUT:
;       EAX = [HANDLE] Created thread
CREATE.THREAD.SIMPLE:

; Call API
push ebx;6; lpThreadId
push ebx;5; dwCreationFlags
push ecx;4; lpParameter; Optional argument
push eax;3; lpStartAddress
push 65536;2; dwStackSize; 64 KB is enough for us
push ebx;1; lpThreadAttributes
Call [CreateThread];:6

Ret


; => Exit process <=
EXIT.PROCESS:

push dword [CODE.EXIT];1
Call [ExitProcess];:1

Ret


; => Exit thread <=
EXIT.THREAD:

; Free additionaly allocated memory
mov eax,[ebp-24]
mov [ebp-32],eax
Call FREE.MEMORY

; Close thread handle and exit
mov eax,[ebp-260]
Call CLOSE.HANDLE

push ebx;1; Exit code
Call [ExitThread];:1

Ret


; => Get file size <=
; IN:
;       EAX = [HANDLE] File
; OUT:
;       ECX = [INT] File size
GET.FILE.SIZE:

; Call API
push ebx;2;lpFileSizeHigh; We do not need files that > 4GB
push eax;1;hFile
Call [GetFileSize];:2

; We add a basic register size just to be sure there's place for additional NT
add eax,BASIC_REGISTER

Ret


; => Override pointers for additional logic thread <=
; Some pointers like DATA, DBOX, LINE must be different from the MAIN thread,
; so we can change them freely without disrupting MAIN logic.
OVERRIDE.POINTERS.THREAD:

; Allocate memory
mov eax,MAX_BUFFER+MAX_DBOX+MAX_LINE+BASIC_REGISTER
Call ALLOCATE.MEMORY

; Now override pointers
mov [ebp-24],eax; Pointer to MAX_DATA
add eax,MAX_BUFFER
mov [ebp-78],eax; Pointer to MAX_DBOX structure [static]
mov [ebp-82],eax; Pointer to MAX_DBOX structure
add eax,MAX_DBOX
mov [ebp-60],eax; Pointer to MAX_LINE structure

Ret


; => Read from handle <=
; IN:
;       EAX = [HANDLE] Read from
;       ECX = [INT] How many bytes to read
;       EDI = [POINTER] Read where [PRESERVED]
; OUT:
;       EAX = [BASIC_REGISTER] Result from API, should be non-zero for success
;       EDI = [POINTER] What we read
;       ECX = [INT] Bytes read
READ.FROM.HANDLE:

; Call API
sub esp,4; Temp buffer for ;4
mov edx,esp
push ebx;5; lpOverlapped
push edx;4; lpNumberOfBytesRead
push ecx;3; nNumberOfBytesToRead
push edi;2; lpBuffer
push eax;1; hFile
Call [ReadFile];:5
pop ecx

Ret


; => Read from pipe <=
; IN:
;       EAX = [HANDLE] Pipe
;       EDI = [POINTER] Read where [PRESERVED]
; OUT:
;       EAX = [BASIC_REGISTER] = 0 if fail, !=0 if success
;       ESI = [POINTER] End of read buffer
READ.FROM.PIPE:

push eax

; Connect pipe
push ebx;2; lpOverlapped
push eax;1; hNamedPipe
Call [ConnectNamedPipe];:2
test eax,eax
je R.F.P.RET; Got error

; Read pipe
mov ecx,[esp]; ECX = Pipe handle
sub esp,4; Temp buffer for ;4
mov eax,esp
push ebx;5
push eax;4; OUT: How many symbols were read
push 8192;3
push edi;2; Arguments
push ecx;1; Pipe handle
Call [ReadFile];:5

; Remove trash and adjust pointer
pop eax; EAX = Bytes read
mov esi,edi
add esi,eax
mov [esi],ebx; Remove trash
Call ACQUIRE.TWO.CHARS

; Disconnect pipe
mov ecx,[esp]; ECX = Pipe handle
push ecx;1; Pipe handle
Call [DisconnectNamedPipe];:1

R.F.P.RET:
add esp,4; Remove Pipe handle

Ret


; => Set up all needed pointers <=
; IN:
;       EAX = [POINTER] Heap
SETUP.POINTERS:

mov [ebp-20],eax; Pointer to arguments [DYNAMIC]
mov [ebp-48],eax; Pointer to arguments [STATIC]
add eax,MAX_ARGUMENTS
mov [ebp-24],eax; Pointer to DATA buffer
add eax,MAX_BUFFER
mov [ebp-52],eax; Pointer MAX_READ
add eax,MAX_READ
mov [ebp-130],eax; Pointer to thread handles
add eax,MAX_THREADS
mov [ebp-12],eax; Pointer to CSBI structure
add eax,MAX_CSBI
mov [ebp-78],eax; Pointer to MAX_DBOX structure [static]
mov [ebp-82],eax; Pointer to MAX_DBOX structure
add eax,MAX_DBOX
mov [ebp-60],eax; Pointer to MAX_LINE structure
add eax,MAX_LINE
mov [ebp-36],eax; Pointer to start of VARS buffer
mov [ebp-40],eax; End of VARS
; Additional pointers
; Current limit for buffer-limited functions, such as CONVERT.BYTES.TO.WIDECHAR
mov dword [ebp-16],MAX_BUFFER

Ret


; => Init thread [BASE] <=
INIT.THREAD.BASE:

; Init stack
xor ebx,ebx;p; EBX always used as a permanent ZERO
mov edx,esp;p
mov dl,0xF0; EDX = Start of the stack
mov ebp,edx; EBP = Start of the stack (NEVER CHANGES!)
pop edx; Current stack
sub esp,1024;sa; Make enough space for important data (1 KB is enough)
push edx; Contains address to return to

; Stack structure initialization
; Must be rewritten! Use of stosd instruction is prohibited!
mov edi,ebp; Clear the should-be-zero stack
sub edi,336; Starting point
xor eax,eax; Clear with zeros
mov ecx,20; Clearing 20 DWORDs
rep stosd; Done

Ret


; => Init thread [ADDITIONAL] <=
; This is needed for every new additional MAIN logic thread
; Currently not implemented
INIT.THREAD.ADD:

; Allocate enough memory
mov eax,MAX_DATA_TOTAL
Call ALLOCATE.MEMORY

; Set up the needed pointers
Call SETUP.POINTERS

; Get thread handle
Call [GetCurrentThread]
mov [ebp-260],eax; It's a thread. We should indicate it by placing thread handle here.

Ret


; => Kill thread <=
; IN:
;       EAX = [HANDLE] Thread
KILL.THREAD:

; Save thread handle
push eax

; Terminate
push ebx;2; Exit code
push eax;1; Thread handle
Call [TerminateThread];:2

; Restore thread handle
pop eax

; Close handle
push eax;1
Call [CloseHandle];:1

Ret


; => Obtain console handles and modes <=
OBTAIN.STD.HANDLES:

; STD IN
push STD_INPUT_HANDLE;1
Call [GetStdHandle];:1
mov [HND.STD.IN],eax
mov [ebp-122],eax; MAIN STDIN handle (used by everyone)

; STD OUT
push STD_OUTPUT_HANDLE;1
Call [GetStdHandle];:1
mov [HND.STD.OUT],eax
mov [ebp-118],eax; MAIN STDOUT handle (used by everyone)

; MODE STD IN
mov ecx,[ebp-122]
Call GET.CONSOLE.MODE
mov [MODE.STD.IN],eax

; MODE STD OUT
mov ecx,[ebp-118]
Call GET.CONSOLE.MODE
mov [MODE.STD.OUT],eax

Ret


; => Open file for reading <=
; IN:
;       ESI = [POINTER] Path to file
; OUT:
;       EAX = [HANDLE] File
OPEN.FILE.FOR.READING:

; Set up flags and call low-level API
mov eax,GENERIC_READ
mov ecx,OPEN_EXISTING
mov edx,FILE_ATTRIBUTE_NORMAL
Call CREATE.FILE

Ret


; => Resume thread <=
; IN:
;       EAX = [HANDLE] Thread
RESUME.THREAD:

push eax;1
Call [ResumeThread];:1

Ret


; => Signal event <=
; IN:
;       EAX = [HANDLE] Event to signal
SET.EVENT:

; Call API
push eax;1
Call [SetEvent];:1

Ret


; => Sleep for a number of milliseconds <=
; IN:
;       EAX = [INT] ms
SLEEP.MS:

push eax;1
Call [Sleep];:1

Ret


; => Suspend system thread <=
; IN:
;       EAX = [HANDLE] Thread
SUSPEND.THREAD:

push eax;1
Call [SuspendThread];:1

Ret


; => Wait for object to trigger <=
; IN:
;       EAX = [HANDLE] Object
;       ECX = [INT] Milliseconds to wait
; OUT:
;       EAX = [BASIC_REGISTER] State: Signaled/Timeout/Error
WAIT.FOR.OBJECT:

; Call API
push ecx;2; dwMilliseconds
push eax;1; hHandle
Call [WaitForSingleObject];:2

Ret


; => Write output to file or console <=
; IN:
;       ESI = [POINTER] Data to write
;       ECX = [INT] Size of data in bytes
; OUT:
;       EAX = [INT] Bytes written
WRITE.TO.FILE:

sub esp,4; Temp output buffer for API
mov eax,esp

; Call API
push ebx;5; lpOverlapped
push eax;4; How many bytes were written
push ecx;3; Counter
push esi;2; Buffer
push dword [ebp-118];1; Appropriate handle
Call [WriteFile];:5

pop eax; EAX = Symbol written counter
Ret