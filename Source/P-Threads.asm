; P-Threads.asm
;
; Copyright (c) 2019, Dmitry Razumovsky (Svarov-RZM)
; You may distribute under the terms of BSD 2-Clause License
; as specified in the LICENSE.TXT file.
;
; >>>=== THREADS ===<<<
; => Logic threads <=
; IN:
;       ESP+4 = [POINTER] Prcoedure string (@) from /H argument
THREAD.LOGIC:

; Init basic registers and stack
mov esi,[esp+4]
Call INIT.THREAD.BASE

; Set up pointers and handles
; Every pointer now equals to MAIN thread (we gotta fix this)
mov eax,HEAP
Call SETUP.POINTERS

; Replace some pointer to our own private memory
; For example, DATA must be different (see procedure below)
Call OVERRIDE.POINTERS.THREAD

; Get our thread id (TID)
; We add position of last handle-C_HANDLE because it
; points to a NEXT (empty) place but we need previous handle
mov edx,[ebp-130]; Pointer to thread handles
add edx,[THREAD.NEXT]
sub edx,C_HANDLE
mov eax,[edx]
mov [ebp-260],eax; EXIT will now call EXIT.THREAD instead

; Setup console handles
mov eax,[HND.STD.IN]
mov [ebp-122],eax
mov eax,[HND.STD.OUT]
mov [ebp-118],eax

; Set initial console buffer state
; Current color, DBOX structure and cursor position
mov edi,[ebp-12]; CSBI struc
Call INIT.INTERNAL.CONSOLE.STATE

; Coorect end ov VARS array, pointer is right after procedure string
push esi
Call SKIP.NT.STRING
mov eax,[esi]
mov [ebp-40],eax
pop esi

; We set up all handles/stack/memory/etc.
; Now we get position of procedure user specified for us
; and jump to it
Call GET.LABEL.VARIABLE
test esi,esi
je EXIT

; Signal MAIN thread that it can continue execution
mov byte [THREAD.SYNC],1

; Correct arguments structure
mov [ebp-28],ecx; Counter of ARGS array [dynamic]
mov [ebp-20],esi; Current ARGS pointer [dynamic]

; We set up stack to contain four zeroes
; This way, when '#' hits, argument counter will be zero and
; so MAIN.LOOP will think it's over and terminate the thread
push ebx
push ebx
push ebx
push ebx

; We are now ready to execute main logic
jmp MAIN.LOOP


; => Read from console  <=
; IN:
;       ESP+4 = [POINTER] Data from /R: argument to process
THREAD.READ:

mov esi,[esp+4]
Call INIT.THREAD.BASE

; Set up pointers and handles
; Now all IN-STACK pointers are valid
mov eax,HEAP
Call SETUP.POINTERS

; Setup console handles
mov eax,[HND.STD.IN]
mov [ebp-122],eax
mov eax,[HND.STD.OUT]
mov [ebp-118],eax

; Split string
xor dx,dx
mov dl,','
Call SPLIT.STRING

; Reset previous states
; [EBP-516] = default choice
mov [READ.CANCEL],bl
mov [ebp-516],ebx

; Check mode
T.R.CHECK.MODE:
Call ACQUIRE.CHAR

cmp ax,'C'
je T.R.READ.CHARS
cmp ax,'K'
je T.R.READ.KEYS
cmp ax,'L'
je T.R.READ.LINES.ECHO
cmp ax,'l'
je T.R.READ.LINES.NOECHO
cmp ax,'T'
je T.R.SET.TIMEOUT

jmp T.R.EXIT

; Read specified amount of chars and print it back
T.R.READ.CHARS:

; Skip ',' delimiter and convert number to binary
Call SKIP.CHAR.FORWARD
Call CONVERT.DECIMAL.STRING.TO.INTEGER

; Read chars
mov ecx,eax
mov esi,[ebp-52]
Call READ.CHARS

jmp T.R.GOT.INPUT

; Read specified amount of keys and print it back
T.R.READ.KEYS:

; Skip ',' delimiter and convert number to binary
Call SKIP.CHAR.FORWARD
Call CONVERT.DECIMAL.STRING.TO.INTEGER

; Read chars
mov ecx,eax
mov edi,esi
mov esi,[ebp-52]
Call READ.KEYS

jmp T.R.GOT.INPUT

; Read line with echo
T.R.READ.LINES.ECHO:
xor ax,ax
mov al,'E'
jmp short T.R.READ.LINES

; Read line without echo
T.R.READ.LINES.NOECHO:
xor ax,ax
mov al,'N'

; Read lines
T.R.READ.LINES:

; Skip ',' delimiter and convert number to binary
push eax
Call SKIP.CHAR.FORWARD
Call CONVERT.DECIMAL.STRING.TO.INTEGER
mov ecx,eax
pop eax

mov esi,[ebp-52]
Call READ.LINES

jmp T.R.GOT.INPUT

; Set timeout for reading
T.R.SET.TIMEOUT:

; Skip ',' delimiter
Call SKIP.CHAR.FORWARD

; Create simple thread for timeout
mov eax,THREAD.READ.ABORT.AFTER
mov ecx,esi
Call CREATE.THREAD.SIMPLE
Call CLOSE.HANDLE

; Skip timeout structure and continue
; [EBP-516] = Default choice
Call SKIP.NT.STRING
mov [ebp-516],esi
Call SKIP.NT.STRING

jmp T.R.CHECK.MODE

; We got some input...
; If READ.CANCEL = 1, then we were interrupted by
; timeout and must place default choice
T.R.GOT.INPUT:

; Signal that we done reading
; Even if we didn't create timeout thread it won't hurt
mov eax,[READ.EVENT]
Call SET.EVENT

; See if we were interrupted
cmp [READ.CANCEL],bl
je T.R.EXIT

; We were interrupted by timeout thread
; Copy default choice
mov esi,[ebp-516]
mov edi,[ebp-52]
Call COPY.NT.STR

; Flush console buffer because we
; wrote two events to it in timeout thread
mov eax,[ebp-122]
Call FLUSH.CONSOLE.INPUT

; Exit thread
T.R.EXIT:
push ebx;1; Exit code
Call [ExitThread];:1


; => Timeout read thread  <=
; IN:
;       ESP+4 = [POINTER] Data from /R: argument to process
THREAD.READ.ABORT.AFTER:

mov esi,[esp+4]
Call INIT.THREAD.BASE

; Set up pointers and handles
; Now all IN-STACK pointers are valid
mov eax,HEAP
Call SETUP.POINTERS

; Setup console handles
mov eax,[HND.STD.IN]
mov [ebp-122],eax
mov eax,[HND.STD.OUT]
mov [ebp-118],eax

; Get timeout in ms
Call CONVERT.DECIMAL.STRING.TO.INTEGER

; Sleep specified amount
; We either will be interrupted by timeout or by upper
; reading thread if it actually got some input
; We exit if we were signaled and interrupt reading if timeout occurred
mov ecx,eax
mov eax,[READ.THREAD]
Call WAIT.FOR.OBJECT
cmp eax,WAIT_TIMEOUT
jne T.R.EXIT

; Set up INPUT_RECORD
add esi,MAX_BUFFER/2
push esi
mov edx,1
xor cx,cx; We don't use key code
xor ax,ax
mov al,0xD; CR
Call PUT.CHAR.TO.CONSOLE.INPUT
mov al,0xA; LF
Call PUT.CHAR.TO.CONSOLE.INPUT
pop esi

; Cancel read
mov byte [READ.CANCEL],1
mov ecx,2
Call WRITE.CONSOLE.INPUT

jmp T.R.EXIT