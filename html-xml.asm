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
;	R15 = Para recorrer el archivo el busca de las etiquetas
;	R14 = Para recorrer el buffer BUFFER_TAGS
;	R9  = Para encontrar los tags de apertura
;	R10 = Para encontrar los tags de cierre
;	RCX = Para almacenar valores que seran situados en BUFFER_TAGS
;	RAX = Para almacenar valores que seran comparados en ValidarTags
;	R11 = Guarda temporalmente la posicion que hace referencia el r9
;	R12 = Guarda temporalmente la posicion que hace referencia el r10
;	RBX = Indice en el buffer de los errores (partido con BL Y BX)
;	BUFFER_TAGS = Almacena todos los tags que se encuentren en el archivo
;	BUFFER_ERRORES = Almacena los tags que no tengan apertura o cierre
;
;************************************************************************************************************

;SECCION DE DATOS SIN INICIALIZAR
section .bss
	bufflen 			equ 4096
	documento 			resb bufflen

	AUXBUFF_LEN 		equ 1024
	BUFFER_TAGS 		resb AUXBUFF_LEN
	BUFFER_ERRORES 		resb AUXBUFF_LEN

;SECCION DE DATOS INICIALIZADOS
section .data

	msjInfo: 			db "Los siguientes TAGS son los errores: ", 10
	msjInfoLen 			equ $-msjInfo

	lines: 				db 10,10
	lineslen 			equ $-lines

;SECCION QUE CONTIENE EL CODIGO
section .text
global _start 	;ETIQUETA GLOBAL QUE NECESITA EL LINKER COMO PUNTO DE ENTRADA

_start:
	readFile documento, bufflen   	;macro que lee el documento
	cmp rax, 0						;si el archivo esta vacio, sale
	je salir

	xor r15, r15	;indice para recorrer el archivo
	xor r14, r14	;indice para recorrer el buffer BUFFER_TAGS
	xor rbx, rbx	;indice en BUFFER_ERRORES

	xor r9, r9		;indice para buscar el < del tag anterior al /
	xor r11, r11	;respaldo del r9
	xor r10, r10	;indice para buscar los /
	xor r12, r12	;respaldo del r10

	call ObtenerTags 		;Guarda todo los tags del archivo en el buffer BUFFER_TAGS

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
			;guardar toda el tag
			.buscarEspacioYGuardar:
				cmp[documento + r15], byte 20H	;cuando encuentra un espacio, es el fin del nombre del tag
				;hacerMatch = encontrar el caracter > que cierra el tag
				je .hacerMatch

				;si no es igual a "espacio", pues se esta guardando el nombre del tag
				mov cl, byte[documento + r15]
				mov byte[BUFFER_TAGS + r14], cl
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
				mov cl, byte[documento + r15]
				mov byte[BUFFER_TAGS + r14], cl
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

				cmp byte[BUFFER_TAGS + r10], 10			;compara si llega al separador "enter"
				je .salirErrorTagCierre

				mov cl, byte[BUFFER_TAGS + r10]			;sino, copia el caracter al BUFFER_ERRORES
				mov byte[BUFFER_ERRORES + rbx], cl
				inc rbx

				mov byte[BUFFER_TAGS + r10], 30H		;agregamos un 0 porque ocupamos omitir lo que ya dio ERROR
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
		mov cl, byte[BUFFER_TAGS + r9]		;se comparan secuencialmente los caracteres
		cmp cl, byte[BUFFER_TAGS + r10]
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
				jae salir

				inc r10
				jmp BuscarBackSlash.loopBuscarBackSlash

;Su funcion es agregar al BUFFER_ERRORES los tags de apertura que no tenian cierre
RevisarBufferErrores:
	xor r8, r8		;el indice en el BUFFER_TAGS

	.cicloRevisarBufferErrores:
		cmp byte[BUFFER_TAGS + r8], 30H		;si no encuentra algo seteado, es porque quedaron errores de tags de apertura
		jne .agregarABufferErrores			;entonces lo agregamos al BUFFER_ERRORES

		inc r8
		cmp r8, r14							;comparar si ya se llego al final del BUFFER_TAGS
		je MostrarInformacion

		jmp .cicloRevisarBufferErrores

	.agregarABufferErrores:
		mov cl, byte[BUFFER_TAGS + r8]
		mov byte[BUFFER_ERRORES + rbx], cl
		inc r8
		inc rbx

		cmp byte[BUFFER_TAGS + r8], 30H
		je .cicloRevisarBufferErrores

		jmp .agregarABufferErrores

MostrarInformacion:
	print lines, lineslen
	print BUFFER_TAGS, r14
	print lines, lineslen
	print msjInfo, msjInfoLen
	print BUFFER_ERRORES, rbx

salir:
	exit