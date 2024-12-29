;
; Librerú} de subrutinas con diversas operaciones aritméticas:
;
; - Arit_VisualizaBinario: Visualiza en el LCD el dato en binario que le entra por W.
; - Arit_Negar: Niega el contenido de un número binario de 16 bits.
; - Arit_Suma_16Bit: Realiza la suma con dos registros de 16 bits.
; - Arit_Resta_16Bit: Realiza la resta con dos registros de 16 bits.
; - Arit_Multiplica_8Bit: Multiplica dos registros de 8 bits.
; - Arit_Multiplica_16Bit: Multiplica dos registros de 16 bits.
; - Arit_Divide_8Bit: Divide dos registros de 8 bits.
; - Arit_Divide_16Bit: Divide un registro de 16 bits entre otro de 7 bits.
; - Arit_BCD_Bin_16Bit: Convierte un número BCD de 5 dú„itos a binario natural de 16 bits.
; - Arit_Bin_BCD_16Bit: Convierte un número binario de 16 bits a BCD de 5 dú„itos.
; - Arit_VisualizaBCD: Visualiza en el LCD un número decimal de varios dú„itos.

	CBLOCK
	Arit_Multiplicando
	Arit_Multiplicador
	Arit_Multiplicando_H				; Byte bajo del operando 1.
	Arit_Multiplicador_H				; Byte bajo del operando 2.
	Arit_Multiplicando_L				; Byte bajo del operando 1.
	Arit_Multiplicador_L
	Arit_Producto_L				; Byte bajo del byte 1 del resultado.
	Arit_Producto_H				; Byte alto del byte 1 del resultado.
	Arit_ContadorBits				; Para realizar diferentes contadores con bits.
	Arit_Dividendo_H
	Arit_Dividendo_L
	Arit_Cociente_H
	Arit_Cociente_L
	Arit_Resto
	Arit_Divisor
;	Arit_Auxiliar					; Registro temporal para realizar operaciones intermedias.
	Arit_Operando_1H
	Arit_Operando_1L
	Arit_Operando_2H			;para resta de 16 bits. Aqui guarda el resultado.
	Arit_Operando_2L
	Arit_Producto_1H		
	Arit_Producto_1L		
	Arit_Producto_2H		
	Arit_Producto_2L

	ENDC

; Subrutina "Arit_Negar" ----------------------------------------------------------------
;
; Niega el contenido de un número de 16 bits almacenado en dos registros
; (Arit_Operando_1H, Arit_Operando_1L).
;
; Lo hace en complemento a 2 por el método clásico, es decir, primero invierte todos los bits
; y después le suma "1".
;
; Se utiliza la instrucción "addwf __", en lugar de "incf ___", porque ésta no posiciona
; el flag de Carry.
;
; En el registro de trabajo W también aparece el resultado de la negación del byte bajo.
;
; Entrada:	En los registros (Arit_Operando_1H, Arit_Operando_1L) el dato de 
;			16 bits a negar.
; Salida: 	En los mismo registros (Arit_Operando_1H, Arit_Operando_1L) el dato de 
;			16 bits negado. En (W) el byte más bajo negado.

Arit_Negar
	comf	Arit_Operando_1H,F		; Invierte los registros que contienen los operandos.
	comf	Arit_Operando_1L,F
	movlw	.1						; Le suma 1.
	addwf	Arit_Operando_1L,F		
	btfsc	STATUS,C				; Si hay acarreo tiene que llevarlo al byte superior.
	incf	Arit_Operando_1H,F	
	movf	Arit_Operando_1L,W		; En (W) el resultado del byte bajo.
	return


; Subrutinas "Arit_Suma_16Bit" y "Arit_Resta_16Bit" ---------------------------------------
;
; Realiza la suma/resta en 16 bits (Operando 2) +/- (Operando 1) y el resultado lo guarda en
; (Operando 2). El resultado lo guarda en 16 bits. Es decir:
; (Arit_Operando_2H, Arit_Operando_2L) +/- (Arit_Operando_1H, Arit_Operando_1L) --> 
; (Arit_Operando_2H, Arit_Operando_2L).
;
Arit_Resta_16Bit
	call	Arit_Negar				; Para la resta, simplemente niega el numero de 16 bits
Arit_Suma_16Bit						; (Arit_Operando_1H, Arit_Operando_1L) y suma.
	movf	Arit_Operando_1L,W		; Suma el byte más bajo.
	addwf	Arit_Operando_2L,F		; y lo guarda en Arit_Operando_2L.
	btfsc	STATUS,C				; Si hay acarreo incrementa en una unidad uno de
	incf	Arit_Operando_1H,F		; de los bytes altos.
	movf	Arit_Operando_1H,W
	addwf	Arit_Operando_2H,F		; Suma el byte alto.
	return


; Subrutinas "Arit_Multiplica_8Bit" ------------------------------------------------------
;
; Realiza la multiplicación del contenido de dos registros de 8 bits. El resultado se almacena
; en 16 bits. La operación se realiza sin signo.
;
; El algoritmo utilizado se basa en el método empleado para efectuar una multiplicación
; manualmente con lápiz y papel. En este método, la multiplicación se lleva a cabo tomando
; un bit del multiplicador, empezando por el menos significativo: 
; - Si es "1" se efectúa la suma del multiplicando y el producto parcial anterior. El producto
;   parcial resultante se desplaza un bit a la derecha, introduciendo un cero por la izquierda.
; - Si es "0" la suma no es necesaria y el producto parcial resultante anterior se desplaza un
;   bit a la derecha, introduciendo además un cero por la izquierda.
;
; Este proceso se repite tantas veces como bits tiene el multiplicador.
;
; Previo a la llamada de esta subrutinas los números a multiplicar se almacenan en los registros
; Arit_Multiplicando y Arit_Multiplicador. El resultado se almacena en 16 bits en los registros 
; (Arit_Producto_H, Arit_Producto_L). Es decir:
; (Arit_Multiplicando) * (Arit_Multiplicador) --> (Arit_Producto_H, Arit_Producto_L)
;
; Se utilizan posiciones de memoria definidas anteriormente, a las que se les cambia el nombre 
; por motivos puramente pedagógicos:



Arit_Multiplica_8Bit
	clrf	Arit_Producto_H			; En principio el resultado es cero.
	clrf	Arit_Producto_L
	movlw	.8						; Carga el contador de 8 bits.
	movwf	Arit_ContadorBits
	movf	Arit_Multiplicando,W	; Carga el multiplicando.
Arit_MultiplicaBit8
	rrf		Arit_Multiplicador,F	; Va a comprobar el siguiente bit del multiplicador.
	btfsc	STATUS,C				; Si el bit del multiplicador es "1"
	addwf	Arit_Producto_H,F		; suma el resultado parcial anterior más el multiplicando.
	rrf		Arit_Producto_H,F		; Desplaza el resultado parcial un lugar hacia la 
	rrf		Arit_Producto_L,F		; derecha, introduciendo un "0" por la izquierda.
	decfsz	Arit_ContadorBits,F		; ¿Ha multiplicado los 8 bits?
	goto	Arit_MultiplicaBit8		; Repite la operación.
	return
	

; Subrutinas "Arit_Multiplica_16Bit" ------------------------------------------------------
;
; Realiza la multiplicación del contenido de dos registros de 16 bits. El resultado se almacena
; en 32 bits. La operación se realizan sin signo.
;
; El algoritmo utilizado es similar al de la multiplicación de 8 bits.
;
; Previo a la llamada de esta subrutinas los números a multiplicar se almacenan en los registros
; (Arit_Multiplicando_H, Arit_Multiplicando_L) y (Arit_Multiplicador_H, Arit_Multiplicador_L).
; El resultado en 32 bits se proporciona en los registros 
; (Arit_Producto_2H, Arit_Producto_2L, Arit_Producto_1H, Arit_Producto_1L).
;
; Se utilizan posiciones de memoria definidas anteriormente, a las que se les cambia el nombre 
; por motivos puramente pedagógicos:

;Arit_Multiplicando_H	EQU	Arit_Operando_1H
;Arit_Multiplicando_L	EQU	Arit_Operando_1L
;Arit_Multiplicador_H	EQU	Arit_Operando_2H
;Arit_Multiplicador_L	EQU	Arit_Operando_2L
;Arit_Producto_1H		EQU	Arit_Resultado_1H
;Arit_Producto_1L		EQU	Arit_Resultado_1L
;Arit_Producto_2H		EQU	Arit_Resultado_2H
;Arit_Producto_2L		EQU	Arit_Resultado_2L

Arit_Multiplica_16Bit
	clrf	Arit_Producto_1H		; En principio el resultado es cero.
	clrf	Arit_Producto_1L
	clrf	Arit_Producto_2H
	clrf	Arit_Producto_2L
	movlw	.16						; Carga el contador de 16 bits.
	movwf	Arit_ContadorBits
Arit_Multiplica16Bit
	rrf		Arit_Multiplicador_H,F	; Va a comprobar el siguiente bit del multiplicador.
	rrf		Arit_Multiplicador_L,F
	btfss	STATUS,C
	goto	Arit_Multiplicador_BitCero
	movf	Arit_Multiplicando_L,W	; Suma en 16 bits el resultado parcial y
	addwf	Arit_Producto_2L,F		; y el multiplicando.
	btfsc	STATUS,C
	incf	Arit_Producto_2H,F
	movf	Arit_Multiplicando_H,W
	addwf	Arit_Producto_2H,F
Arit_Multiplicador_BitCero
	rrf		Arit_Producto_2H,F		; Desplaza el resultado parcial un lugar hacia la 
	rrf		Arit_Producto_2L,F		; derecha, introduciendo un "0" por la izquierda.
	rrf		Arit_Producto_1H,F
	rrf		Arit_Producto_1L,F
	decfsz	Arit_ContadorBits,F		; ¿Ha multiplicado los 16 bits?
	goto	Arit_Multiplica16Bit	; Repite la operación.
	return



; Subrutinas "Arit_Divide_16Bit" --------------------------------------------------------
;
; Realiza la división del contenido del dividendo de 16 bits entre un divisor de 7 bits.
; El máximo valor del divisor serE127.
;
; Se utiliza el mismo algoritmo explicado para la subrutina Arit_Divide_8bit.
;
; Entradas:
; 	- (Arit_Dividendo_H) y (Arit_Dividendo_L) que hacen de dividendo de 16 bits.
;	- (Arit_Divisor) que es el divisor de 7 bits, (máximo b'01111111'=0x7F=d'127').
; Salidas:
;	- (Arit_Cociente_H) y (Arit_Cociente_L) que hacen de cociente de 16 bits.
;	- (Resto) de 8 bits.
;	- (W), en el registro de trabajo también el resto.
;
; La división se harEsin signo y el programa que le llame deberEdetectar que el divisor no
; es cero. El divisor serEde 7 bits, es decir su valor máximo serE
; b'01111111'=0x7F=d'127'.
;
; Se utilizan posiciones de memoria definidas anteriormente, a las que se les cambia el nombre 
; por motivos puramente pedagógicos:
;


Arit_Divide_16Bit
	clrf	Arit_Cociente_H			; En principio el resultado es cero.
	clrf	Arit_Cociente_L
	clrf	Arit_Resto
	movlw	.16						; Carga el contador.
	movwf	Arit_ContadorBits
Arit_DivideBit16
	rlf		Arit_Dividendo_L,F
	rlf		Arit_Dividendo_H,F
	rlf		Arit_Resto,F			; (Arit_Resto) contiene el dividendo parcial.
	movf	Arit_Divisor,W
	subwf	Arit_Resto,W			; Compara dividendo parcial y divisor.
	btfsc	STATUS,C				; Si (dividendo parcial)>(divisor)
	movwf	Arit_Resto				; (dividendo parcial) - (divisor) --> (dividendo parcial)
	rlf		Arit_Cociente_L,F		; Desplaza el cociente introduciendo el bit apropiado
	rlf		Arit_Cociente_H,F		; "0" E"1" según corresponda.
	decfsz	Arit_ContadorBits,F
	goto	Arit_DivideBit16
	movf	Arit_Resto,W			; El resto también en (W).
	return
	
