; P-Memory.asm
;
; Copyright (c) 2019, Dmitry Razumovsky (Svarov-RZM)
; You may distribute under the terms of BSD 2-Clause License
; as specified in the LICENSE.TXT file.
;
; >>>=== MEMORY-SPECIFIC PROCEDURES ===<<<
; => Get WORD <=
; IN:
;       ESI = [POINTER] WORDs
; OUT:
;       AX = [WORD]
GET.WORD:
GET.CHAR:; Alias

mov ax,[esi]

Ret


; => Acquire BYTE <=
; IN:
;       ESI = [POINTER] BYTEs
; OUT:
;       ESI = [POINTER] Next BYTE
;       AL = [BYTE]
ACQUIRE.BYTE:

mov al,[esi]
inc esi

Ret


; => Acquire WORD <=
; IN:
;       ESI = [POINTER] WORDs
; OUT:
;       ESI = [POINTER] Next WORD
;       AX = [WORD]
ACQUIRE.WORD:
ACQUIRE.CHAR:; Alias

mov ax,[esi]
add esi,2

Ret


; => Acquire WORD backward <=
; IN:
;       ESI = [POINTER] WORDs
; OUT:
;       AX = [WORD]
ACQUIRE.WORD.BACKWARD:
ACQUIRE.CHAR.BACKWARD:; Alias

sub esi,2
mov ax,[esi]

Ret


; => Acquire WORD backward at position <=
; IN:
;       ESI = [POINTER] WORDs
;       ECX = [INT] How many WORDs to skip back
; OUT:
;       ESI = [POINTER] Next WORD
;       AX = [WORD]
ACQUIRE.WORD.BACKWARDS.AT:
ACQUIRE.CHAR.BACKWARDS.AT:; Alias

mov eax,esi
sub eax,ecx
sub eax,ecx

mov ax,[eax]

Ret


; => Acquire DWORD <=
; IN:
;       ESI = [POINTER] DWORDs
; OUT:
;       ESI = [POINTER] Next DWORD
;       EAX = [DWORD]
ACQUIRE.DWORD:
ACQUIRE.NUMBER:; Alias
ACQUIRE.TWO.CHARS:; Alias

mov eax,[esi]
add esi,4

Ret


; => Acquire MAIN heap pointer <=
ACQUIRE.HEAP.POINTER:

Call [GetProcessHeap];:0
mov [HND.HEAP],eax; Heap handle

Ret


; => Allocate memory from default heap <=
; IN:
;       EAX = [INT] Size to allocate
; OUT:
;       EAX = [POINTER] Allocated space
ALLOCATE.MEMORY:

; For compatibility with COPY.MEM.GENERAL that copy memory by 4
add eax,4

; Call API
push eax;3; Size
push ebx;2; Flags
push dword [HND.HEAP];1; Process heap handle
Call [HeapAlloc];:3

; Set last pointer
; FREE.MEMORY uses it by default
mov [ebp-32],eax

Ret


; => Free previously allocated memory <=
; IN:
;       EBP-32 = [POINTER] What to free
FREE.MEMORY:

; Call API
push dword [ebp-32];3; Last pointer here
push ebx;2; Flags
push dword [HND.HEAP];1; Process heap handle
Call [HeapFree];:3

Ret


; => Collapse memory (bytes) <=
; Collapses array in memory by a specified number of bytes
; IN:
;       ESI = [POINTER] [1]: Memory to collapse [PRESERVED]
;       EAX = [POINTER] [2]: End of array in Pointer [1]
;       ECX = [INT] [3]: Number of bytes to exclude [PRESERVED]
; OUT:
;       EAX = [POINTER] End of collapsed memory
COLLAPSE.MEMORY.BYTES:

test ecx,ecx; Immediately return if counter is zero
je CL.M.B.RET

push edi

; Set up pointers
; EDI = Pointer: Starting point
; ESI = Pointer: Offset: [1] + [3]
; ECX = Counter: [2] - Calculated offset (ESI)
mov edi,esi
add esi,ecx
sub eax,esi
xchg ecx,eax

; EDI = Pointer: Memory to collapse
; ESI = Pointer: Skipped characters
CL.M.B.COPY:
Call COPY.MEM.GENERAL
mov eax,edi; End of collapsed memory

pop edi

CL.M.B.RET:
Ret


; => Collapse memory (words) <=
; Collapses array in memory by a specified number of words
; IN:
;       ESI = [POINTER] Memory to collapse (Start) [PRESERVED]
;       EAX = [POINTER] Memory to collapse (End)
;       ECX = [INT] Number of words to exclude [PRESERVED]
; OUT:
;       EAX = [POINTER] End of collapsed memory
COLLAPSE.MEMORY.WORDS:

test ecx,ecx; Immediately return if counter is zero
je CL.M.W.RET

push edi; Preserve EDI
push esi; Preserve ESI

mov edi,esi
add esi,ecx; EDI = Pointer: Start of data to collapse
add esi,ecx
mov ecx,esi
sub eax,ecx
mov ecx,2
Call DIVIDE.INTEGER
xchg ecx,eax

; EDI = Pointer: Memory to collapse
; ESI = Pointer: Skipped characters
CL.M.W.COPY:
Call COPY.MEM.WORDS
mov eax,edi; End of collapsed memory

pop esi; Restore ESI
pop edi; Restore EDI

CL.M.W.RET:
Ret


; => Compare two words array <=
; IN:
;       ESI = [POINTER] SRC string [PRESERVED]
;       EDI = [POINTER] DST string [PRESERVED]
;       ECX = [INT] WORDS to compare [PRESERVED]
; OUT:
;       EAX = [DWORD] 0 - Differ, 1 - Equal
COMPARE.WORDS:
COMPARE.CHARS:; Alias

push esi
push edi

; Comparing
C.W.LOOP:
test ecx,ecx
je C.W.RET.GOOD; All words matched
mov ax,[esi]; Load word from SRC
cmp [edi],ax; Compare to DST
jne C.W.RET.BAD; Arrays differ

; Correcting arrays
mov eax,2; Replace it with EDX for optimization purpose? Why I decided to use EAX anyway?
dec ecx; One WORD processed
add esi,eax; Next WORD in SRC
add edi,eax; Next WORD in DST
jmp short C.W.LOOP; Compare again

; Different
C.W.RET.BAD:
xor eax,eax
jmp short C.W.RET

; Same
C.W.RET.GOOD:
mov eax,1

C.W.RET:
pop edi
pop esi
Ret


; => Copy memory in optimized way <=
; We copy by 4 bytes (better to be BASIC_REGISTER though). Make sure buffers
; have additional 4 bytes in the end so we won't get access violation errors.
; IN:
;       ESI = [POINTER] Copy what [1]
;       EDI = [POINTER] Copy where [2]
;       ECX = [INT] Size of buffer in bytes [3] [PRESERVED]
; OUT:
;       ESI = [POINTER] End of SRC buffer (varies by 4 bytes)
;       EDI = [POINTER] End of DST buffer
;       EAX = [POINTER] Start of DST buffer where we copied string
COPY.MEM.GENERAL:

; Immediately leave on zero counter
test ecx,ecx
je C.M.G.RET

; Save [2] and [3]
push edi
push ecx

; Copy from SRC to DST
C.M.G.LOOP:

mov eax,[esi]; EAX = 4 bytes to copy
mov [edi],eax; Place at new buffer
sub ecx,4; 4 bytes were copied
je C.M.G.FIN; ZERO = All copied
js C.M.G.FIN; SIGN = Copied more than was asked to
add esi,4; Next DWORD in SRC
add edi,4; Next DWORD in DST

jmp short C.M.G.LOOP

; Restore [2] and [3] and correct pointers
C.M.G.FIN:
pop ecx
pop eax
mov edi,eax
add edi,ecx

C.M.G.RET:
Ret


; => Copy memory by words <=
; IN:
;       ESI = [POINTER] Copy what
;       EDI = [POINTER] Copy where
;       ECX = [INT] Size of buffer
; OUT:
;       ESI = [POINTER] End of SRC buffer
;       EDI = [POINTER] End of DST buffer
;       EAX = [POINTER] Start of DST buffer where we copied string
COPY.MEM.WORDS:
COPY.CHARACTERS:; Alias

; Immediately leave on zero counter
test ecx,ecx
je C.M.W.RET

push edi; We'll restore it to EAX at the end

; Copy from SRC to DST
C.M.W.LOOP:
mov ax,[esi]; EAX = 2 bytes to copy
mov [edi],ax; Place at new buffer
dec ecx; 1 word copied
je C.M.W.FIN; ZERO = All copied
add esi,2; Next WORD in SRC
add edi,2; Next WORD in DST
jmp short C.M.W.LOOP

; Finalizing
C.M.W.FIN:
add esi,2; Next WORD in SRC
add edi,2; Next WORD in DST
pop eax; EAX = Start of DST buffer

C.M.W.RET:
Ret


; => Copy memory by DWORDS <=
; IN:
;       ESI = [POINTER] Copy what
;       EDI = [POINTER] Copy where
;       ECX = [INT] Size of buffer
; OUT:
;       ESI = [POINTER] End of SRC buffer
;       EDI = [POINTER] End of DST buffer
;       EAX = [POINTER] Start of DST buffer where we copied data
COPY.MEM.DWORDS:

; Immediately leave on zero counter
test ecx,ecx
je C.M.D.RET

push edi; We'll restore it to EAX at the end

; Copy from SRC to DST
C.M.D.LOOP:

mov eax,[esi]; EAX = 2 bytes to copy
mov [edi],eax; Place at new buffer
dec ecx; 1 DWORD copied
je C.M.D.FIN; ZERO = All copied
add esi,4; Next DWORD in SRC
add edi,4; Next DWORD in DST

jmp short C.M.D.LOOP

; Finalizing
C.M.D.FIN:
add esi,4; Next DWORD in SRC
add edi,4; Next DWORD in DST
pop eax; EAX = Start of DST buffer

C.M.D.RET:
Ret


; => Expand specified numbers of WORDs specified number of times <=
; IN:
;       ESI = [POINTER] WORDs to expand
;       EDI = [POINTER] Expand where
;       EAX = [INT] How many WORDs to expand [PRESERVED in ECX]
;       ECX = [INT] Expand number of times
; OUT:
;       ESI = [POINTER] WORDs to expand [END]
;       EDI = [POINTER] Expand where [END]
;       AL = [BYTE] True or False (if counter was zero)
EXPAND.WORDS.LOOPED:

; Check prerequisites and prepare variables
test ecx,ecx; Counter can't be zero
je E.W.S.T.RET.BAD
mov edx,eax
push esi; Start of data
push edx; Counter of word structure to expand

; Loop over all words
E.W.S.T.LOOP:
test edx,edx
je E.W.S.T.AGAIN; Wrap structure at ESI
test ecx,ecx
je E.W.S.T.END; Completed

; Save word
Call ACQUIRE.WORD
mov [edi],ax
add edi,2; Next place to save
dec edx; One WORD written
dec ecx; One global WORD written
jmp short E.W.S.T.LOOP

; Wrap structure at ESI
E.W.S.T.AGAIN:
test ecx,ecx
je E.W.S.T.END; Completed
mov edx,[esp]; Counter of structure to expand
mov esi,[esp+4]; Start of data
jmp short E.W.S.T.LOOP

; Finalizing
E.W.S.T.END:
xchg edx,ecx
Call SKIP.WORDS; Correct if ECX=0 but EDX!=0. In that case we are in a middle of ESI structure
pop ecx
add esp,4; Remove Start of data
mov al,1
jmp short E.W.S.T.RET

E.W.S.T.RET.BAD:
xor al,al

E.W.S.T.RET:
Ret


; => Fill memory with specified WORD <=
; IN:
;       AX = [WORD] Fill with
;       EDI = [POINTER] Fill where
;       ECX = [INT] Times to fill
; OUT:
;       EDI = [POINTER] End of buffer
;       EAX = [POINTER] Start of buffer
FILL.WORDS:
FILL.CHARS:; Alias

push edi; Preserve start of buffer

; Immediately leave on zero counter
test ecx,ecx
je F.W.RET

; Fill memory
F.W.LOOP:
mov [edi],ax
Call SKIP.CHAR.FORWARD.DST
dec ecx
test ecx,ecx
jne F.W.LOOP

; Done
F.W.RET:
pop eax
Ret


; => Rewind character (source) <=
; IN:
;       ESI = [POINTER] Where to rewind
; OUT:
;       ESI = [POINTER] ESI - 1 char
REWIND.WORD:
REWIND.CHAR:; Alias

dec esi
dec esi

Ret


; => Rewind character (destination) <=
; IN:
;       EDI = [POINTER] Where to skip chars
; OUT:
;       EDI = [POINTER] EDI - 1 char
REWIND.WORD.DST:
REWIND.CHAR.DST:; Alias

dec edi
dec edi

Ret


; => Rewind WORDs (destination) <=
; IN:
;       EDI = [POINTER] Where to rewind
;       ECX = [INT] Words to rewind
; OUT:
;       EDI = [POINTER] Next position
REWIND.WORDS.DST:
REWIND.CHARACTERS.DST:; Alias

sub edi,ecx
sub edi,ecx

Ret


; => Replace all words in array <=
; IN:
;       DX = [WORD] Search this
;       AX = [WORD] Replace with this
;       ESI = [POINTER] Search where [PRESERVED]
;       ECX = [INT] Length of array in ESI
; OUT:
;       AL = [BYTE] 0 - Fail, !0 - Success
;       ECX = [INT] Words from start to a place we performed replacement in the last match
REPLACE.WORD.GLOBAL:
REPLACE.CHAR.GLOBAL:; Alias

; Preserve ESI and AX
push esi
push eax

; Set up callback
mov eax,R.W.G.CALLBACK
Call LOOP.OVER.MATCHED.CHARS

; Remove AX and restore original pointer
add esp,4
pop esi

Ret

; Replace all matches
R.W.G.CALLBACK:

; Replace with AX
mov eax,[esp+16]
mov [esi],ax

; True = continue running
mov al,1

Ret


; => Search for DWORD <=
; IN:
;       EDX = [DWORD] Search what
;       ESI = [POINTER] Search where
;       ECX = [INT] Counter of array in ESI
; OUT:
;       EAX = [DWORD] 0 - Fail, 1 - Success
;       ECX = [INT] Characters left
;       ESI = [POINTER] Place we found requested DWORD
SEARCH.DWORD:

; Searching
SD.W.LOOP:
test ecx,ecx; Counter is zero, return
je SD.W.RET.BAD

cmp [esi],edx; Compare DWORD with source
je SD.W.RET.GOOD; Found

add esi,4; Next DWORD
dec ecx; 1 DWORD processed
jmp short SD.W.LOOP

; Didn't find
SD.W.RET.BAD:
xor eax,eax
jmp short SD.W.RET

; Found!
SD.W.RET.GOOD:
mov eax,1

SD.W.RET:
Ret


; => Search for WORD <=
; IN:
;       DX = [WORD] Search what
;       ESI = [POINTER] Search where
;       ECX = [INT] Counter of array in ESI
; OUT:
;       AL = [BYTE] 0 - Fail, != 0 - Success
;       ECX = [INT] Words left
;       ESI = [POINTER] Place we found requested WORD
SEARCH.WORD:
SEARCH.CHAR:; Alias

; Set up callback for each word
mov eax,S.W.LOOP
Call LOOP.OVER.WORDS

; Check for error
test ecx,ecx
je S.W.RET.BAD
mov al,1
jmp short S.W.RET

S.W.RET.BAD:
xor al,al

S.W.RET:
Ret

; Callback: AX = WORD
; We break if we found requested word
; So, if ECX != 0 then word is found
S.W.LOOP:

; Compare word with source
cmp ax,dx
jne S.W.CONT
; WORD found, break cycle
xor al,al
Ret

; Do not match, continue search
S.W.CONT:
mov al,1
Ret


; => Search for a specified set of WORDs <=
; IN:
;       ESI = [POINTER] Search what [PRESERVED]
;       EAX = [INT] Size of ESI array
;       EDI = [POINTER] Search where
;       ECX = [INT] Size of EDI array
; OUT:
;       AL = [BYTE] 0 - Fail, 1 - Success
;       ECX = [INT] WORDs left
;       EDI = [POINTER] Place we found requested set of WORDs
SEARCH.WORDS:
SEARCH.CHARS:; Alias

push eax
push esi

; Searching
S.WS.LOOP:
test ecx,ecx; Counter is zero, return
je S.WS.RET.BAD

; Seek for the first WORD
mov ax,[esi]
xchg esi,edi
xchg ax,dx
Call SEARCH.WORD

; Break if we couldn't even find the first WORD
test al,al
je S.WS.RET.BAD

; Preserve total counter
mov edx,ecx

; Set 'Search what' counter
mov ecx,[esp+4]

; Compare the rest
xchg esi,edi
Call COMPARE.WORDS

; Restore total counter
mov ecx,edx

; Restore 'Search what'
mov esi,[esp]

; Check if matched
test al,al
jne S.WS.RET.GOOD; All right, found it!

; We must skip current matching word so SEARCH.WORD won't return it again
Call SKIP.WORD.FORWARD.DST
dec ecx
jmp short S.WS.LOOP

; Didn't find
S.WS.RET.BAD:
xor al,al
jmp short S.WS.RET

; Got it
S.WS.RET.GOOD:
mov al,1

; Clear stack and return
S.WS.RET:
add esp,8
Ret


; => Skip WORDs forward (source) <=
; IN:
;       ESI = [POINTER] Where to skip
;       ECX = [INT] Skip number of WORDs
; OUT:
;       ESI = [POINTER] Next position
SKIP.WORDS:
SKIP.CHARACTERS:; Alias

add esi,ecx
add esi,ecx

Ret


; => Skip WORDs forward (destination) <=
; IN:
;       EDI = [POINTER] Where to skip
;       ECX = [INT] Number of WORDs to skip
; OUT:
;       EDI = [POINTER] Next position
SKIP.WORDS.DST:
SKIP.CHARACTERS.DST:; Alias

add edi,ecx
add edi,ecx

Ret


; => Skip WORD forward (source) <=
; IN:
;       ESI = [POINTER] Where to skip
; OUT:
;       ESI = [POINTER] Next WORD
SKIP.WORD.FORWARD:
SKIP.CHAR.FORWARD:; Alias

inc esi
inc esi

Ret


; => Skip WORD forward (destination) <=
; IN:
;       ESI = [POINTER] Where to skip WORDs
; OUT:
;       ESI = [POINTER] Next WORD
SKIP.WORD.FORWARD.DST:
SKIP.CHAR.FORWARD.DST:; Alias

inc edi
inc edi

Ret