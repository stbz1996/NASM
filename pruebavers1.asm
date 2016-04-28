%include "macros.mac"

section .bss
	bufflen equ 4096
	documento resb bufflen

	buffEtiquetaLen equ 1024
	bEtiqueta resb buffEtiquetaLen
	
	

section .text

global _start

					_start:
; CONTADOR QUE PASA POR LOS 4K DEL DOCUMENTO ES.... r15


	leerDocumentos documento, bufflen   ;macro que lee el documento
	cmp rax, 0
	je salir	
	mov rbp, rax

	xor r15, r15

BuscaMenorQue:
	cmp[documento + r15], byte 0x3C ;busca < en el documento
	je BuscarEspacio
	inc r15
	jmp BuscaMenorQue

	 

	;.BuscaMayorQue:
	;	  cmp [documento + r15],0x3E
	;	  je funcion de buscar el otro
	;	  inc r15
	;	  jmp .analisis


imprimir:
	mov rax, 1
	mov rdi, 1
	mov rsi, bEtiqueta
	mov rdx, r14
	syscall


salir:
	mov rax, 60
	mov rdi, 0
	syscall



BuscarEspacio:
	push r15
	push rcx

	.buscarEspacioYGuardar:	
			; r14 CONTADOR PARA EL BUfFER
		xor rcx, rcx
		cmp[documento + r15], byte 20h
		je .retornar
		mov rcx, [documento + r15]
		mov [bEtiqueta + r14], rcx
		inc r14
		inc r15
		jmp .buscarEspacioYGuardar

	.retornar:
		pop rcx
		pop r15
		jmp imprimir
	












