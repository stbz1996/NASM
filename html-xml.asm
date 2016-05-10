;****************************************************
;		INSTITUTO TECNOLÓGICO DE COSTA RICA			*
;													*
;		Arquitectura de Computadores - Grupo 40		*
;													*
;		Profesor: Erick Hernández B.				*
;                                                   *
;		Primer Proyecto NASM: Verificador HTML/XML	*
;													*
;		Estudiantes: Steven 	Bonilla				*
;                    Mauricio 	Castillo V.			*
;                    Randy 		Morales G.			*
;													*
;		Semestre I - 2016							*
;													*
;****************************************************

%include "macros.mac"
; el archivo macros incluye: readFile, print, exit
; el nombre de cada una indica su funcion


;*****************************	INFORMACION DEL USO DE REGISTROS Y MEMORIA	*********************************
;	
;	RAX (AL) = Para almacenar valores que seran comparados y movidos entre memoria y registros.
;	RBX = FILA
;	RCX = COLUMNA

;	R8  = Indice para el BUFFER_POS
;	R9  = Para encontrar los tags de apertura | Imprimir fila/columna en la parte de los errores
;	R10 = Para encontrar los tags de cierre	  | Imprimir fila/columna en la parte de los errores
;	R11 = Guarda temporalmente la posicion que hace referencia el r9
;	R12 = Guarda temporalmente la posicion que hace referencia el r10
;	R13 = Para recorrer el buffer BUFFER_ERRORES
;	R14 = Para recorrer el buffer BUFFER_TAGS
;	R15 = Para recorrer el archivo en busca de las etiquetas

;	BUFFER_TAGS = Almacena todos los tags que se encuentren en el archivo
;	BUFFER_ERRORES = Almacena los tags que no tengan apertura o cierre
;	BUFFER_POS = Guarda las posiciones de los tags, y se utiliza para la info de error con fila/columna
;
;************************************************************************************************************

;SECCION DE DATOS SIN INICIALIZAR
section .bss
	DOC_LEN 			equ 4096
	documento 			resb DOC_LEN

	BUFFER_LEN 			equ 1024
	BUFFER_TAGS 		resb BUFFER_LEN
	BUFFER_ERRORES 		resb BUFFER_LEN

;SECCION DE DATOS INICIALIZADOS
section .data

	msjInfo: 			db "Los siguientes TAGS son los errores: ", 10
	msjInfoLen 			equ $-msjInfo

	msjErrorFila: 		db " ERROR EN LA FILA: "
	msjErrorFilaLen		equ $-msjErrorFila

	msjErrorCol:		db " Y LA COLUMNA: "
	msjErrorColLen		equ $-msjErrorCol

	lines: 				db 10,10
	lineslen 			equ $-lines

	FILA_COLUMNA_LEN 	equ 4
	FILA: 				db "0000"
	COLUMNA: 			db "0000"

;SECCION QUE CONTIENE EL CODIGO
section .text
global _start 	;ETIQUETA GLOBAL QUE NECESITA EL LINKER COMO PUNTO DE ENTRADA

_start:
	readFile documento, DOC_LEN   	;macro que lee el documento
	cmp rax, 0						;si el archivo esta vacio, sale
	je salir

	xor r9, r9		;indice para buscar el < del tag anterior al /
	xor r10, r10	;indice para buscar los /
	xor r11, r11	;respaldo del r9
	xor r12, r12	;respaldo del r10
	xor r13, r13	;indice en BUFFER_ERRORES
	xor r14, r14	;indice para recorrer el buffer BUFFER_TAGS	
	xor r15, r15	;indice para recorrer el archivo	

	call ObtenerTags 		;Guarda todo los tags del archivo en el buffer BUFFER_TAGS
	;print BUFFER_TAGS, r14
	jmp BuscarBackSlash 	;Busca el caracter / que indica un tag de cierre (Aqui se inicia toda la verificacion)
		
;***************************************	PROCEDIMIENTOS	*****************************************

;Su funcion es buscar y almacenar todos los tags del documento, en el formato <a>\n</a>...
ObtenerTags:
	;busca el inicio de la etiqueta (el <)
	.BuscaMenorQue:

		cmp[documento + r15], byte 3CH ;busca < en el archivo
		je .BuscarEspacio
		cmp[documento + r15], byte 0H	;si se llega al final del archivo, salir
		je .salirObtenerTags
		inc r15
		jmp .BuscaMenorQue

		;busca el final del tag
		.BuscarEspacio:

			;guardar todo el tag
			.buscarEspacioYGuardar:
				cmp[documento + r15], byte 0H	;si se llega al final del archivo, salir
				je .salirObtenerTags

				cmp[documento + r15], byte 20H	;cuando encuentra un espacio, es el fin del nombre del tag
				;hacerMatch = encontrar el caracter > que cierra el tag
				je .hacerMatch

				;si no es igual a "espacio", pues se esta guardando el nombre del tag
				mov al, byte[documento + r15]
				mov byte[BUFFER_TAGS + r14], al
				inc r14
				inc r15
				cmp byte[documento + r15-1], 3EH 	;esto se agrega porque hace un inc extra, y se ocupa verificar si ya esta en ">"
				;retornar = ya guardo el tag con el formato <a> o </a>, entonces hay que buscar otro en caso de que hayan mas en el doc.
				je .retornar
				jmp .buscarEspacioYGuardar

			;buscar el > del tag de cierre
			.hacerMatch: 
				cmp [documento + r15], byte 3EH	; >
				;salvarCaracter = simplemente agrega el > y procede a buscar otro tag en el documento
				je .salvarCaracter
				cmp byte[documento + r15], 3CH	; <
				je .retornar
				inc r15
				jmp .hacerMatch

			;agrega el > al buffer y busca otro tag
			.salvarCaracter:
				mov al, byte[documento + r15]
				mov byte[BUFFER_TAGS + r14], al
				inc r14
				inc r15
				jmp .retornar

			;Buscar otro tag en el documento
			.retornar:
				mov [BUFFER_TAGS + r14], byte 10	;mueva un retorno de carro para separar los tags (<a>\n<b>...) 
				inc r14
				cmp [documento + r15], byte 0H		;verifique si se llego al final del documento, si aun falta, siga buscando tags
				jb .BuscaMenorQue

			;verifica si ya se llega al final del archivo
			.salirObtenerTags:
				cmp byte[documento + r15], 0H	;se llega al final del archivo
				jne .BuscaMenorQue
				ret

;Su funcion es encontrar el caracter / que indica un tag de cierre
BuscarBackSlash:
	.loopBuscarBackSlash:
		cmp[BUFFER_TAGS + r10], byte 0H	;si se llega al final del archivo, salir
		je RevisarBufferErrores

		cmp r10, r14		;si buscando el / llega al final del doc, es decir, no encontro mas tags de cierre
		je RevisarBufferErrores

		cmp byte[BUFFER_TAGS + r10], 2FH ;/
		jne .incR10

		lea r9, [r10 - 2]		;siempre se le asigna al r9 el valor de r10-2 (usualmente queda en el separador "enter" del BUFFER_TAGS)
		jmp BuscarTagAnterior 	;ya encontrado el tag de cierre, revisemos si el anterior es el que hace pareja

		;incrementa r10 hasta que encuentre el /
		.incR10:
			inc r10
			jmp .loopBuscarBackSlash

;Su funcion es encontrar el caracter < al encontrar el / lo que indica que se comparara que los tags sean pareja
BuscarTagAnterior:
	.loopBuscarTagAnterior:
		cmp r9, -1			; -1 significa que r9 llego al inicio del BUFFER_TAGS y no encontro el < del tag de apertura
		je .errorTagCierre	;si no se encuentra el < es porque no hay cierre del tag hasta el inicio

		cmp byte [BUFFER_TAGS + r9], 3CH ; al encontrar el < se comparan los nombres de los tags
		je .salirTagAnterior

		dec r9							;si no es < entonces siga buscando hacia atras
		jmp .loopBuscarTagAnterior

		.salirTagAnterior:		;guardamos los indices r9 y r10 por si la comparacion da ERROR
			mov r11, r9
			mov r12, r10		;guardar la posicion de r9, r10
			inc r9
			inc r10
			jmp ValidarTags

		.errorTagCierre:		;el tag de cierre no tiene el de apertura (ERROR)
			dec r10				;para que inicie en el < del tag

			.loopErrorTagCierre:

				cmp r10, r14		;compara si llega al final
				ja IndicarErrores

				cmp byte[BUFFER_TAGS + r10], 10			;compara si llega al separador "enter"
				je .salirErrorTagCierre

				;mov al, byte[BUFFER_TAGS + r10]			;sino, copia el caracter al BUFFER_ERRORES
				;mov byte[BUFFER_ERRORES + r13], al
				;inc r13

				;mov byte[BUFFER_TAGS + r10], 30H		;agregamos un 0 porque ocupamos omitir lo que ya dio ERROR
				inc r10
				jmp .loopErrorTagCierre

				;termina de setear el tag que dio error y busca de nuevo el /
				.salirErrorTagCierre:
					mov byte[BUFFER_TAGS + r10], 30H
					inc r10
					jmp BuscarBackSlash

;Su funcion es validar los nombres del tag de apertura y del tag de cierre
ValidarTags:
	.cicloValidarTags:
		mov al, byte[BUFFER_TAGS + r9]		;se comparan secuencialmente los caracteres
		cmp al, byte[BUFFER_TAGS + r10]
		je .continuarValidarTags

		;en caso de no ser iguales, se recuperan las posiciones de los indices r9 y r10
		;y se comprueba si el que da error es el tag de cierre o el de apertura (saltando a buscar un tag anterior)

		mov r9, r11
		dec r9
		mov r10, r12
		jmp BuscarTagAnterior

		;si las letras de ambos tags son iguales, verificar si ya llegamos al final (al caracter >)
		.continuarValidarTags:
			cmp byte[BUFFER_TAGS + r9], 3EH ;con >
			je .removerTagsBuenos

			;en caso de ser cierto, simplemente los seteamos porque no los necesitamos
			;sino, entonces siga comparando los caracteres siguientes

			inc r9
			inc r10
			jmp .cicloValidarTags

		;ponermos 0 a los tags que estan bien, aqui se recuperan las posiciones de los indices r9 y r10
		.removerTagsBuenos:
			mov r10, r12
			dec r10
			mov r9, r11			;recuperar valores de los indices

			mov byte[BUFFER_TAGS + r10], 30H
			mov byte[BUFFER_TAGS + r9], 30H		;poner 1 tanto al < del tag de apertura como al de cierre

			inc r9
			inc r10

			.cicloRemoverTagsBuenos:

				mov byte[BUFFER_TAGS + r10], 30H
				mov byte[BUFFER_TAGS + r9], 30H		;poner 0 tanto al tag de apertura como al de cierre

				inc r9
				inc r10

				;cuando llegamos al carater > hay que acomodar los indices para poder seguir buscando tags
				cmp byte[BUFFER_TAGS + r9], 3EH
				je .ubicarIndices

				jmp .cicloRemoverTagsBuenos

			;acomodar los indices para poder seguir buscando tags
			.ubicarIndices:
				mov byte[BUFFER_TAGS + r10], 30H
				mov byte[BUFFER_TAGS + r9], 30H

				inc r9
				inc r10

				mov byte[BUFFER_TAGS + r10], 30H
				mov byte[BUFFER_TAGS + r9], 30H

				inc r10
				mov byte[BUFFER_TAGS + r10], 30H
				;este ultimo inc se debe a que el tag de cierre contiene un caracter de mas
				;(el / que no tiene el tag de apertura)

				cmp r10, r14	;se compara si sobrepaso el final del BUFFER_TAGS, sino, a buscar otro /
				jae MostrarInformacion

				inc r10
				jmp BuscarBackSlash.loopBuscarBackSlash

;Su funcion es agregar al BUFFER_ERRORES los tags de apertura que no tenian cierre
RevisarBufferErrores:
	mov r14, -1		; resetear el indice en el BUFFER_TAGS

	.cicloRevisarBufferErrores:
		inc r14
		cmp byte[BUFFER_TAGS + r14], 0H		;comparar si ya se llego al final del BUFFER_TAGS
		je IndicarErrores

		cmp byte[BUFFER_TAGS + r14], 30H	;si no encuentra algo seteado, es porque quedaron errores de tags de apertura
		je .cicloRevisarBufferErrores			;entonces lo agregamos al BUFFER_ERRORES

		cmp byte[BUFFER_TAGS + r14], 31H	;el caracter 1 en este caso nos sirve para la cantidad de tags que hay en total
		je .cicloRevisarBufferErrores		;entonces no lo agregamos al BUFFER_ERRORES

		;jmp .agregarABufferErrores

	.agregarABufferErrores:
		mov al, byte[BUFFER_TAGS + r14]
		mov byte[BUFFER_ERRORES + r13], al
		inc r14
		inc r13

		cmp byte[BUFFER_TAGS + r14], 30H
		je .cicloRevisarBufferErrores		

		cmp byte[BUFFER_TAGS + r14], 0H		;comparar si ya se llego al final del BUFFER_TAGS
		je IndicarErrores

		jmp .agregarABufferErrores


;Su funcion es la de mostrar los errores en pantalla, con el formato fila / columna
IndicarErrores:
	mov byte[BUFFER_ERRORES + r13], 10
	inc r13
	mov r8, r13		;respaldo largo BUFFER_ERRORES
	xor r13, r13 	;resetear el indice del BUFFER_ERRORES
	xor r15, r15 	;resetear el indice del documento
	xor rax, rax

	xor r9, r9 		;FILA
	xor r10, r10 	;COLUMNA

	xor r11, r11 	;Respaldo FILA
	xor r12, r12	;Respaldo COLUMNA

	xor rbp, rbp 	;Respaldo de R13

	.cicloIndicarErrores:
		;se guardan los valores para la impresion del ERROR
		mov r11, r9
		mov r12, r10
		mov rbp, r13
		cmp byte[documento + r15], 3CH 		;con <
		je .compararContenidoTag

		cmp byte[documento + r15], 10 		;con el enter
		je .modificarFC 					;FC Fila Columna

		cmp byte[documento + r15], 0H
		je MostrarInformacion

		inc r15
		inc r10
		jmp .cicloIndicarErrores

	.modificarFC:
		inc r9				;FILA + 1
		xor r10, r10 		;COLUMNA = 0
		inc r15

		jmp .cicloIndicarErrores

	.compararContenidoTag:

		cmp byte[documento + r15], 0H
		je .imprimirError

		cmp byte[BUFFER_ERRORES + r13], 0H
		je .imprimirError

		cmp byte[documento + r15], 3EH 		; con >
		je .imprimirError

		mov al, byte[BUFFER_ERRORES + r13]
		cmp al, byte[documento + r15]

		jne .salirCompararContenidoTag

		inc r13
		inc r15
		inc r10 	;COLUMNA

		jmp .compararContenidoTag

		.salirCompararContenidoTag:
			inc r15
			inc r10
			mov r13, rbp
			jmp .cicloIndicarErrores


	.imprimirError:
		print lines, lineslen
		print msjErrorFila, msjErrorFilaLen

		mov rax, r11
		mov rsi, FILA
		call itoa
		print FILA, FILA_COLUMNA_LEN

		print msjErrorCol, msjErrorColLen
		mov rax, r12
		mov rsi, COLUMNA
		call itoa
		print COLUMNA, FILA_COLUMNA_LEN


		cmp byte[documento + r15], 0H
		je MostrarInformacion

		add r13, 2
		inc r15
		inc r10

		call LimpiarBuffer
		jmp .cicloIndicarErrores

MostrarInformacion:
	print lines, lineslen
	print msjInfo, msjInfoLen
	print BUFFER_ERRORES, r8

salir:
	exit

itoa:
	push rdx
	push rcx
	push rax

	lea rcx, [FILA_COLUMNA_LEN - 1]
	mov rbx, 10

	cmp rax, 0
	je .salirItoa

	.cicloItoa:
		xor rdx, rdx    				; se limpia porque se ocupa en la division RDX:RAX
		div rbx		   					; el cociente se queda en el rax y el residuo en el RDX
		add dl, '0'     				; se convierte el residuo a ascii
		mov [rsi + rcx], dl   			; mover el caracter a la direccion donde esta el buffer
		dec rcx        					; Decrementa el apuntador

		cmp rax, 0   					; verifica que el rax es cero. Si lo es la bandera ZF se modifica	
		jnz .cicloItoa       			; Salta si bandera del ZF se modifica! si rax!=0

	.salirItoa:
	pop rax
	pop rcx
	pop rdx
	ret

LimpiarBuffer:
	push rcx
	xor rcx, rcx
	.cicloLimpiarBuffer:
		mov byte[FILA + rcx], '0'
		mov byte[COLUMNA + rcx], '0'
		inc rcx
		cmp rcx, 4
		jb .cicloLimpiarBuffer

	pop rcx
	ret