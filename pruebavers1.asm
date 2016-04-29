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
	mov rbp, rax	;RBP guarda el tamaño del documento
	xor r15, r15

BuscaMenorQue:	;busca el inicio de la etiqueta (el <)
	cmp[documento + r15], byte 0x3C ;busca < en el documento
	je BuscarEspacio
	cmp[documento + r15], byte 0h
	je imprimir
	inc r15
	jmp BuscaMenorQue

BuscarEspacio:	;busca el final de la etiqueta
	push rcx
	.buscarEspacioYGuardar:	;guardar toda la etiqueta
		; r14 CONTADOR PARA EL BUfFER
		xor rcx, rcx
		cmp[documento + r15], byte 20h
		je .hacerMatch
		
		mov rcx, [documento + r15]
		mov [bEtiqueta + r14], rcx
		inc r14
		inc r15
		cmp [documento + r15-1], byte 3Eh
		je .retornar
		jmp .buscarEspacioYGuardar

	.hacerMatch: ;buscar el > del tag de cierre 
		cmp [documento + r15], byte 3Eh	; >
		je .salvarCaracter
		cmp [documento + r15], byte 3Ch	; <
		je .retornar
		inc r15
		jmp .hacerMatch

	.salvarCaracter:
		mov rcx, [documento + r15]
		mov [bEtiqueta + r14], rcx
		inc r14
		inc r15
		jmp .retornar

	.retornar:
		pop rcx
		;mov [bEtiqueta + r14], byte 3Eh
		;inc r14
		cmp r15, rbp
		jb	BuscaMenorQue

;*****************************************************************************************************
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
