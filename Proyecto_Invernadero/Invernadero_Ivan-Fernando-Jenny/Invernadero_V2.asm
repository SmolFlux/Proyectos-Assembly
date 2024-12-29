LIST      p=16F877A ; Define el microcontrolador
INCLUDE   <p16F877A.inc> ; Incluye la librería del PIC16F877A

__CONFIG  _XT_OSC & _WDT_OFF & _PWRTE_ON & _BODEN_OFF & _LVP_OFF ; Configuración de fusibles
     
     CBLOCK 0x20	
		Retardoini			; retardo inicial
		TEMPL				;Registro bajo de temperatura
		TEMPH				;Registro alto de temperatura
		HUMH				;Registro alto de humedad
		HUML				;Registro bajo de humedad
		;MULTH				;Resultado de 8 bits de la multiplicacion	- ALTO
		;MULTL				;Resultado de 8 bits de la multiplicacion	- BAJO
		TEMPF2L				;Registro FINAL bajo de temperatura
		TEMPF2H				;Registro FINAL alto de temperatura
		TEMPFL				;Registro FINAL bajo de temperatura
		TEMPFH				;Registro FINAL alto de temperatura
		HUMFH				;Registro FINAL alto de humedad
		HUMFL				;Registro FINAL bajo de humedad
		Auxiliar
     ENDC							;Se crean distintas variables para evitar confusiones y sobrescrituras incorrectas
									;- - - - - - A MEJORAR  - - - - - - ;
;-----------------------------------;Variables temporales y de uso común
;LCD = PORTD para datos - PORTE para RW, RS y E.
;ADC PORTA - Usaremos AN0 para el LM35.
;ADC PORTA - Usaremos AN1 para el HW-080
;Ocuparemos solamente TEMPL; esto ya que no encontraremos temperaturas mayores a 120 grados celcius
	;Este es un registro de 8 bits el cual deberemos de multiplicar por 100.
;Para el sensor de humedad parece que tambien se multiplica por 100; por lo que sera le mismo procedimiento.
					
					;---------OBSERVACIONES---------Usando solo 8 bits----;
					;Desface n : cuando lectura <10 - n = 1 aprox
					;Desface n : cuando lectura <20 - n = 4 aprox
					;Desface n : cuando lectura <30 - n = 6 aprox
					;Desface n : cuando lectura >30 - n = 8 aprox
					;Desface exp. debido al manejo incompleto de bits; se usan 8 bits por practicidad - AJUSTE NECESARIO	
					;Esto ya que si no el registro final seria > 24 bits
					;Complejidad manejo LCD es mayor mientras M > 10 bits
					;-----------------------------------------------------;
	org 0x00				
	call LCD_Inicializa		;Iniciamos el LCD
	call LIMPIA_REG			;Limpieza en cada ciclado
INICIO						;configurar ADC
	bsf STATUS,RP0     		;seleccione Banco 1
    bsf TRISA,0				;Activamos AN0 - Sensor Temperatura 
	bsf TRISA,1				;Activamos AN1 - Sensor Humedad
	movlw	b'10000010'		;Just.Der, Fosc/8, D=AN7,6,5 AD=AN4,3,2,1,0
							;ADFM/ADCS2/0/0/PCFG3/PCFG2/PCFG1/PCFG0
	movwf	ADCON1			;registro 1 de configuraciòn A/D 
	
    bcf     STATUS,RP0     	;seleccione Banco 0
;-----------------------------------;Se configura ADCON1
	movlw	b'01000000'		;Fosc/8, Canal AN0, GO_Done, 0, AD_ON OFF
							;ADCS1/ADCS0/CHS2/CHS1/CHS0/GO_DONE/0/ADON
	movwf	ADCON0			;registro 0 de configuraciòn A/D
	bsf		ADCON0,ADON		;enciende el ADC
	
							;hacer retardo inicial de Tacq
							;retardo de tiempo de adquisicion de al menos 19.72 us
							;20us (Tcy=1us, a 4MHz) son 20*Tcy de espera
;-----------------------------------;Se configura el ADCON0
	call RETARDO_CARGA
;-----------------------------------;Retardo de carga para el circuito interno RC
CONVERSION
;-----------------------------------;Punto de ciclaje
	bcf STATUS,RP0
	bcf ADCON0,3
;-----------------------------------;Cambio de canal al AN0 al momento de ciclar
GUARDAR_TEMP
	call RETARDO_CARGA
	call CONVERSION_ADC				;Iniciamos la conversion ADC en el canal AN0
	movf ADRESH, 0
	movwf TEMPH
;-----------------------------------;Guardamos la parte alta de la muestra - Temperatura
	bsf STATUS, RP0
	movf ADRESL, 0
	bcf STATUS, RP0
	movwf TEMPL	
	call CALCULO_TEMP				;Calculamos el valor de la temperatura
;-----------------------------------;Termina de leer el LM35 y ahora lee el HW-080
	bcf STATUS,RP0
	bsf ADCON0,3
;-----------------------------------;Cambio de canal de AN0 a AN1
GUARDAR_HUM	
	call RETARDO_CARGA
	call CONVERSION_ADC				;Iniciamos la conversion ADC en el canal AN1
	movf ADRESH, 0
	movwf HUMH
;-----------------------------------;Guardamos la parte alta de la muestra - Humedad
	bsf STATUS, RP0
	movf ADRESL, 0
	bcf STATUS, RP0
	movwf HUML
	call CALCULO_HUM
goto VISUALIZAR_DATOS
;-----------------------------------;Guardamos la parte baja de la muestra - Humedad
VISUALIZAR_DATOS
	call LCD_Borra
	movlw M0
	call LCD_Mensaje
	call LCD_UnEspacioBlanco			;Temperatura: 
	movf TEMPF2L,W						;Ahora se visualiza en decimal.
	call BIN_a_BCD						;Primero se convierte a BCD.
	movwf Auxiliar						;Guarda las decenas y unidades.
	movf BCD_Centenas,W					;Visualiza centenas.
	call LCD_Nibble						
	movf Auxiliar,W						;Visualiza las decenas y unidades.
	call LCD_ByteCompleto				
	Call LCD_UnEspacioBlanco
	movlw M2
	call LCD_Mensaje

	
	call LCD_Linea2
	movlw M1
	call LCD_Mensaje
	call LCD_UnEspacioBlanco			;Humedad: 
	movf HUMFH,W						;Ahora se visualiza en decimal.
	call BIN_a_BCD						;Primero se convierte a BCD.
	movwf Auxiliar						;Guarda las decenas y unidades.
	movf BCD_Centenas,W					;Visualiza centenas.
	call LCD_Nibble						
	movf Auxiliar,W						;Visualiza las decenas y unidades.
	call LCD_ByteCompleto
	Call LCD_UnEspacioBlanco
	movlw M3
	call LCD_Mensaje

	call Retardo_2s						;Retardo antes de refresco				
goto CONVERSION																		;¿DONDE ESTA EL ERROR FATAL?
;-----------------------------------;Ciclamos la conversion ADC
CALCULO_TEMP
	movf TEMPL
	movwf Arit_Multiplicando_L 		;Cargamos la parte baja para la multiplicacion
	movf TEMPH
	 movwf Arit_Multiplicando_H 		;Cargamos la parte baja para la multiplicacion
	movlw d'100'
	movwf Arit_Multiplicador_L		;Multiplicamos TEMPL por 100
	movlw d'0'
	movwf Arit_Multiplicador_H
	call Arit_Multiplica_16Bit
;-----------------------------------;Sección para multiplicar y sacar temperatura (se multiplica por 100)
	movf Arit_Producto_2H,0
	movwf TEMPF2H
	movf Arit_Producto_2L,0
	movwf TEMPF2L	
	movf Arit_Producto_H,0
	movwf TEMPFH
	movf Arit_Producto_L,0
	movwf TEMPFL
return
;-----------------------------------;Subrutina para calculo de temperatura
CALCULO_HUM
	movf HUML
	movwf Arit_Multiplicando 		;Cargamos la parte baja para la multiplicacion
	movlw d'100'
	movwf Arit_Multiplicador		;Multiplicamos HUML por 100
	call Arit_Multiplica_8Bit
;-----------------------------------;Sección para multiplicar y sacar humedad (se multiplica por 100)
	movf Arit_Producto_H,0
	movwf HUMFH
	movf Arit_Producto_L,0
	movwf HUMFL
AJUSTE_HUM
	;movlw d'8'						;Ajuste fijo para grados inferiores a 25 aproximado 
	;addwf HUMFH					;					Error de calculo (?) - Verificar
	call REAJUSTE_HUM				;Ajuste dependiente de la parte alta
return
;-----------------------------------;Subrutina para calculo de humedad
REAJUSTE_TEMP
	movlw d'1'
	addwf TEMPFH
	decfsz TEMPH,f					;Dependiendo el contenido de TEMPH se realiza un ajuste a la medida final TEMPHF
	goto REAJUSTE_TEMP
return
;-----------------------------------;Subrutina de reajuste dependiendo el resultado 
REAJUSTE_HUM
	movlw d'1'
	addwf HUMFH
	decfsz HUMH,f					;Dependiendo el contenido de HUMH se realiza un ajuste a la medida final TEMPHF
	goto REAJUSTE_HUM
return
;-----------------------------------;Subrutina de reajuste dependiendo el resultado 
CONVERSION_ADC
	bsf		ADCON0,GO_DONE	;Comienza la conversion
	btfsc	ADCON0,GO_DONE	;GO_DONE = 0 - Termina conversion y salta
	GOTO		$-1			;Siempre y cuando no acabe, regresamos
return
;------------------------------------;Subrutina para inicio de conversion ADC
Mensajes 
		addwf PCL,F
	M0
		DT "Temperatura: ", 0x00
	M1
		DT "Humedad: ", 0x00
	M2
		DT "C",0x00
	M3
		DT "%",0x00
;-----------------------------------;Mensajes
RETARDO_CARGA
	movlw	d'20'			;carga valor 20 decimal
	movwf	Retardoini	    ;en retardo inicial
Retardo
   	decfsz  Retardoini,f    ;decremente retardo inicial
    goto    Retardo   		;si no termina ciclo, va a Retardo
return						;una vez termina, se cumplen los 20us y regresamos
;-----------------------------------;Retardo Inicial para el ADC = 20us
LIMPIA_REG
	clrf TEMPL				;Registro bajo de temperatura
	clrf TEMPH				;Registro alto de temperatura
	clrf HUMH				;Registro alto de humedad
	clrf HUML				;Registro bajo de humedad
	;clrf MULTH				;Resultado de 8 bits de la multiplicacion	- ALTO
	;clrf MULTL				;Resultado de 8 bits de la multiplicacion	- BAJO
	clrf TEMPFL				;Registro FINAL bajo de temperatura
	clrf TEMPFH				;Registro FINAL alto de temperatura
	clrf HUMFH				;Registro FINAL alto de humedad
	clrf HUMFL				;Registro FINAL bajo de humedad
return 
;-----------------------------------;Subrutina de limpieza de variables	
	INCLUDE	<ARIT.INC>
	INCLUDE <BIN_BCD.INC>			;Para mandar constantes al LCD, debemos convertir a BCD
	INCLUDE <LCD_MENS.INC>			
	INCLUDE <LCD_4BIT_16F877_D_E.INC>
	INCLUDE <RETARDOS.INC> 
;-----------------------------------;Librerias
END