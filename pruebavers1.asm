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
	je RecorrerBufferEtiqueta
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
		mov [bEtiqueta + r14], byte 10
		inc r14
		cmp r15, rbp
		jb BuscaMenorQue





RecorrerBufferEtiqueta:
	; este procedimiento toma cada tag y lo compara con el tag anterior
	; para colocar los contadores adeuados y validar o mostrar el error
	; registros contadores
		; - r8
		; - r9
		; - r10
		; - r11
	push r8
	push r9
	push r10
	push r11	
	push rax

	mov r8, 0 ;r8 apunta al inicio del buffer
	mov r9, 1 ; r9 va a apuntar  la primera letra de cada tag de apertura
	mov r10, 2; solo inicio del r10
	xor rax, rax

	.BuscarBackSlash:
		cmp [bEtiqueta + r10], byte 2fh 
		jne .repetir	
		lea r9, [r10 - 2]	
		jmp .BuscarTagAnterior

	.repetir:
		inc r10
		jmp .BuscarBackSlash
	
	.BuscarTagAnterior:
		cmp [bEtiqueta + r9], byte 3ch 
		je .ValidarTags
		dec r9
		jmp .BuscarTagAnterior

	.ValidarTags:
		; poner los < en 1 para conteo
		mov byte [bEtiqueta + r9], 31h
		mov byte [bEtiqueta + r10 - 1], 31h
	
	.cicloValidarTags:
		; incrementamos para tener la primer letra de cada tag
		inc r9
		inc r10

		mov al, byte [bEtiqueta + r9]
		cmp al, byte [bEtiqueta + r10]
		jne imprimir
		;si son iguales
			; ponga ceros o unos
		mov byte [bEtiqueta + r9],30h
		mov byte [bEtiqueta + r10],30h
		jmp .cicloValidarTags
		
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
