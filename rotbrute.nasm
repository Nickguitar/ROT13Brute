;Nicholas Ferreira - 18/08/21
;ROT13 bruteforce
;Prints all 26 ROT variations of the input
;
;Run via ./rotbrute <file> or via pipe
;E.g: echo -n "docdo" | ./rotbrute
;
;This code was not intended to be the best
;and it's probably the worst. I'm learning =)

global _start

; =============== DEFINITIONS

READ equ 	0
WRITE equ	1
OPEN equ	2
FSTAT equ	5
MMAP equ	9
EXIT equ	60
BUF equ 	2048		;stdin buffer
MREMAP equ	25

; ================ MACROS

%macro exit 0
	mov rax, 60
	mov rdi, 0
	syscall
%endmacro

%macro open 3			;open filepath, flags, perm
	push %1				;filepath
	push %2				;flags(ro)
	push %3				;perm
	call _open
	add rsp, 24			;clear stack
%endmacro

%macro filesize 1		;filesize fd
	mov rdi, %1			;save fd in rdi
	call _filesize
%endmacro

%macro mmap 2			;mmap length
	push %1				;addr (let kernel decide)
	push %2				;length
	push 0x2			;prot (PROT_WRITE)
	push 33				;flags (MAP_SHARED|MAP_ANONYMOUS)
	push -1				;fd (ignore)
	push 0				;offset (0, because MAP_ANONYMOUS)
	call _mmap			;map memory to load its own content
	add rsp, 48			;clear stack
%endmacro

%macro read 3			;read fd, buf, count
	push %1				;fd
	push %2				;buf (addr of mapped memory)
	push %3				;count (from filesize)
	call _read
	add rsp, 24			;clear stack
%endmacro

%macro write 3
	push %1				;fd
	push %2				;buf
	push %3				;count
	call _write
	add rsp, 24			;clear stack
%endmacro

%macro mremap 3
	push %1				;old addr
	push %2				;old size
	push %3				;new size
	push 0				;flags
	push 0				;new addr
	call _mremap
	add rsp, 40			;clear stack
%endmacro

; ================ DATA AND BSS

section .data
	usage: db 'Usage: ./rotbrute [filename]', 0
	error: db 'File not found',0
	nl: db 0xA,0
	zero: db '0 ',0

; ================ FUNCTIONS

section .text
	_open:
		push rbp
		mov rbp, rsp
		mov rax, OPEN
		mov rdx, [rbp+16]	;perm
		mov rsi, [rbp+24]	;flags
		mov rdi, [rbp+32]	;filepath
		syscall
		leave
		ret			;result goes in rdi

	_filesize:
		push rbp
		mov rbp, rsp
		sub rsp, 192		;reserved for stat() return
		mov rax, FSTAT
		mov rsi, rsp		;statbuf
		syscall
		mov rax, [rsp+48]	;the filesize will be at this position on stack
		leave
		ret

	_mmap:
		push rbp
		mov rbp, rsp
		mov rax, MMAP
		mov r9, [rbp+16]	;offset
		mov r8, [rbp+24]	;fd
		mov r10, [rbp+32]	;flags
		mov rdx, [rbp+40]	;prot
		mov rsi, [rbp+48]	;length
		mov rdi, [rbp+54]	;addr
		syscall
		leave
		ret

	_mremap:
		push rbp
		mov rbp, rsp
		mov rax, MREMAP
		mov r8, [rbp+16]	;old addr
		mov r10, [rbp+24]	;old size
		mov rdx, [rbp+32]	;new size
		mov rsi, [rbp+40]	;flags
		mov rdi, [rbp+48]	;new addr
		syscall
		leave
		ret

	_read:
		push rbp
		mov rbp, rsp
		mov rax, READ
		mov rdx, [rbp+16]	;count (size)
		mov rsi, [rbp+24]	;buf
		mov rdi, [rbp+32]	;fd
		syscall
		leave
		ret

	_write:
		push rbp
		mov rbp, rsp
		mov rax, WRITE
		mov rdx, [rbp+16]	;count
		mov rsi, [rbp+24]	;buf
		mov rdi, [rbp+32]	;fd
		syscall
		leave
		ret

	;the procedure below does something like
	;this (for both upper and lowercase):
	;
	;str = 'string read from file'
	;charset = 'abcdefghijklmnopqrstuvxwyz'
	;i=0;
	;while(i<27)
	;	for(j=0;j<=strlen(str);j++)
	;		if(str[j] == 'z')
	;			str[j] = 'a'
	;		else
	;			str[i] = charset[j+1]
	;	i++

	_magic:				;encode/decode
		push rbp
		mov rbp, rsp
		mov rax, [rbp+8]	;mem addr with file contents
		mov rbx, [rbp+16]	;filesize
		push rbx		;save filesize for later
		add rbx, rax		;addr+filesize
		push rax		;popped at the end

		mov rcx, 1		;ROT index
	_checkz:
		cmp byte [rax],0x7A	;check if current char n is 'z'
		jnz _checkZ		;if not, go check if it's a capital 'z'
		mov byte [rax],0x60	;if so, set current char to before 'a'
	_checkZ:
		cmp byte [rax],0x5A	;check if current char is 'Z'
		jnz _checkSpace		;if not, go check if it's a space
		mov byte [rax],0x40	;if so, set current char to before 'A'
	_checkSpace:
		cmp byte [rax],0x20	;check if current byte is 0x20 (space)
		jnz _checkNL		;if not, continue normally
		jmp _isSpace		;if so, do not add 1
	_checkNL:
		cmp byte [rax], 0xA
		jnz _checkNum1
		jmp _isSpace		;ignore newlines
	_checkNum1:
		cmp byte [rax], 0x30
		jge _checkNum2		;ignore numbers
	_checkNum2:
		cmp byte [rax], 0x39
		jle _isSpace
	_continue:
		add byte [rax], 1	;add 1 to char (e.g: a+1 = b)
	_isSpace:
		inc rax			;move char to next position >>
		cmp rax, rbx		;is the current position the end?

		jle _checkz		;if not, goto next byte
		mov rdx, [rsp]		;mov string encoded to rdx
		mov r9, [rsp+8]		;filesize
		push rax		;saving...
		push rcx		;saving...
		push rdx		;saving...

		jz _magic
		write 1, rdx, r9	;print the encoded string
		write 1, nl, 2		;print newline
		pop rdx			;retrieving...
		pop rcx			;retrieving...
		pop rax			;retrieving...
		inc rcx			;next index
		mov rax, rdx		;make rax its initial value
		cmp rcx, 25		;25 bc/ original was already printed
		jle _checkz		;if index >=25, repeat
		pop rax			;retrieve addr
		exit
		leave
		ret

	_checkStdin:			;verify if is len(stdin)>0
		push rbp
		mov rbp, rsp
		mmap 0, BUF		;allocate a mem buffer to receive stdin
		mov r14, rax
		mov r15, rax		;this will be incremented
		push rax		;saves addr of mapped mem
		read 0, rax, BUF	;tries to read from stdin
		cmp rax, 0		;if it read more than 0 bytes
		jnz _hasStdin		;then there is stdin
		jmp _usage

	_hasStdin:
		push BUF

	_loop:				;this will read the stdin every 100 bytes 
        				;and increase the size of the memory allocated as needed
		pop rcx			;old size
		pop rax			;addr of mapped mem
		mov rbx, rcx		;save old size
		add rcx, BUF		;new size = old size + BUF
		push rcx		;save new file (will be the next old)
		mremap rax, rbx, rcx    ;remap (increase allocated mem size)
		pop rcx
		push rax		;addr of mapped mem
		push rcx
		add r15, BUF
		read 0, r15, BUF
		cmp rax, 0		;if it read more than 0 bytes
		jnz _loop
		mov r9, rbx		;move size to r9 and rax
		mov rax, rbx
		mov rdx, r14		;mov mem addr to rdx
		leave
		ret

	_usage:
		write 1, usage, 29
	_exit:
		exit
	_notfound:
		write 1, error, 15
		exit
; ================ MAIN

	_start:
		pop rax			;argc
		cmp rax, 2		;if argc >= 2

		jge _hasArgument	;	there are arguments
		call _checkStdin	;else, check if there is stdin
		jmp _begin

	_hasArgument:			;read file from first argument
		mov rax, [rsp+8]	;argv[1]
		push rax		;save argv on stack
		open rax, 0, 0		;path, flags (R/W), perm
		cmp rax, 0		;fd
		jl _notfound		;if fd<0 then exit
		push rax 		;save fd in stack
		filesize rax		;get filesize from fd = n
		cmp rax, 0
		jz _exit		;exit if filesize = 0

		push rax		;save filesize (n) in stack
		mmap 0,rax		;maps n bytes

		mov rcx, [rsp]		;filesize
		mov rbx, [rsp+8]	;fd
		mov rdx, rax		;pointer to allocated memory
		push rdx		;save this pointer in stack
		push rdx
		read rbx, rax, rcx
		mov r9, rax		;save number of bytes read
		pop rdx			;retrieve pointer to memory

	_begin:
		push rax
		push rdx
		write 1, rdx, rax	;print with index 0
		write 1, nl, 1		;print newline
		jmp _magic		;encode/decode
