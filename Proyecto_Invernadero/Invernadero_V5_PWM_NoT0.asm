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
		RESH
		RESL
     ENDC						
	
	#DEFINE BOMBITA	PORTC,1	
;-----------------------------------;Variables temporales y de uso común
;LCD = PORTD para datos - PORTE para RW, RS y E.
;ADC PORTA - Usaremos AN0 para el LM35.
;ADC PORTA - Usaremos AN1 para el HW-080
;Ocuparemos solamente TEMPL; esto ya que no encontraremos temperaturas mayores a 120 grados celcius.
	;Este es un registro de 8 bits el cual deberemos de multiplicar por 100.
;Para el sensor de humedad parece que tambien se multiplica por 100; por lo que sera le mismo procedimiento.
;PWM - CCP2 - RC1 al 70% 
					
					;---------OBSERVACIONES---------Usando solo 8 bits----;
;TEMPERATURA
;Nosotros sabemos que nuestra temperatura estará entre 0 y 1023, sin embargo no sabemos la cantidad de bits que representan
;nuestra muestra; por lo que tenemos que calcularla. Si 5V son los 1024 bits; cuanto será el valor que obtenemos del sensor?

;Digamos que obtenemos una lectura 35 grados, el LM35 nos dará 0.35V, simplemente sacamos una regla de 3:
;				(0.35V)(1024bits)									     (35'C)(ValorLeido)(bits)
;		Bits = ------------------ = 61.44 bits	:Ahora se calcula la T = ------------------------ = ValorLeido * 0.48
;					   5V													    61.44 bits

;El 0.48 es una constante que se mantiene en cualquier temperatura en la cual se realice el despeje, por lo que la tomamos 
;para nuestros calculos.

;HUMEDAD
;En el HW-080 mientras más cerca este el valor medido a 1023, más seco estará el ambiente
					;-----------------------------------------------------;
	org 0x00				
	call LCD_Inicializa		;Iniciamos el LCD
	call LIMPIA_REG			;Limpieza en cada ciclado
	call LIMPIEZA_ADC
;-----------------------------------;Limpiamos por si acaso el ADRES al cambiar de canal
INICIO						;configurar ADC
	bsf STATUS,RP0     		;seleccione Banco 1
	bcf BOMBITA				;Habilitamos CCP2 - RC1	
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
TIMR2_CONFIG
		clrf T2CON			;Limpia registro T2CON
		movlw b'00000101'	;Configura T2CON: Postescalar 1:1,Prescaler 1:4, Timer2 ON
    	movwf T2CON			;Carga en T2CON
;-----------------------------------;Subrutina de limpieza para el timer2
PWM 
		call LIMPIAR_PWM	;Configuracion del PWM	
    	movlw 0x3D       	;Valor para PR2 segun la frecuencia deseada del PWM
    	movwf PR2
    	movlw 0xFA          ;Ciclo de trabajo del PWM 70%
    	movwf CCPR1L
    	movlw b'00001100' 	;Configura CCP2CON para modo PWM
    	movwf CCP1CON	
;-----------------------------------;Subrutina de PWM - Siempre estará prendida y el LDR permitirá el paso a la bombita
CONVERSION
;-----------------------------------;Punto de ciclaje
	bcf STATUS,RP0
	bcf ADCON0,3
;-----------------------------------;Cambio de canal al AN0 al momento de ciclar
	call LIMPIEZA_ADC
;-----------------------------------;Limpiamos por si acaso el ADRES al cambiar de canal
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
	call LIMPIEZA_ADC
;-----------------------------------;Limpiamos por si acaso el ADRES al cambiar de canal
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
	movf TEMPFL,W						;Ahora se visualiza en decimal.
	call BIN_a_BCD						;Primero se convierte a BCD.
	movwf Auxiliar						;Guarda las decenas y unidades.
	call AJUSTE							;Ajuste de 1 visualizado en la simulacion
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
	movf HUMFL,W						;Ahora se visualiza en decimal. - prueba
	;movf RESL,W							;Ahora se visualiza en decimal. - prueba
	call BIN_a_BCD						;Primero se convierte a BCD.
	movwf Auxiliar						;Guarda las decenas y unidades.
	call AJUSTE							;Ajuste de 1 visualizado en la simulacion
	movf BCD_Centenas,W					;Visualiza centenas.
	call LCD_Nibble						
	movf Auxiliar,W						;Visualiza las decenas y unidades.
	call LCD_ByteCompleto
	Call LCD_UnEspacioBlanco
	movlw M3
	call LCD_Mensaje

	call Retardo_2s						;Retardo antes de refresco				
goto CONVERSION	
;-----------------------------------;Ciclamos la conversion ADC
CALCULO_TEMP
	movf TEMPL,0						;Usamos el nibble bajo de la muestra, podemos ignorar los 2 bits mas significativos
	movwf Arit_Multiplicando
	movlw d'48'							;Constante obtenida de la regla de 3 en bits 
	movwf Arit_Multiplicador
	call Arit_Multiplica_8Bit
	movf Arit_Producto_H,0				
	movwf Arit_Dividendo_H
	movf Arit_Producto_L,0
	movwf Arit_Dividendo_L
										;No es posible multiplicar por 0.48, por lo que primero se multiplica por 48 y despues se divide por 100
	movlw d'100'						;Dividimos entre 100 ya que no es posible multiplicar por 0.48
	movwf Arit_Divisor	
	call Arit_Divide_16Bit				;Una vez dividido sería como solo multiplicar TEMPL por 0.48
	movf Arit_Cociente_L,0 				;Usamos solo la parte baja del resultado, este abarca de 0 a 255
	movwf TEMPFL						
return
;-----------------------------------;Subrutina para calculo de temperatura
CALCULO_HUM
	movf HUML,0
	movwf Arit_Multiplicando
	movlw d'48'
	movwf Arit_Multiplicador
	call Arit_Multiplica_8Bit
	movf Arit_Producto_H,0
	movwf Arit_Dividendo_H
	movf Arit_Producto_L,0
	movwf Arit_Dividendo_L
	
	movlw d'100'
	movwf Arit_Divisor
	call Arit_Divide_16Bit
	movf Arit_Cociente_L,0 			
	movwf HUMFL
	movf Arit_Cociente_H,0			
	movwf HUMFH
	;call AJUSTE_HUM					;Recordemos que mientras mayor sea la muestra, entonces mas seco estará
									;Debemos arreglar la logica
return
;-----------------------------------;Subrutina para calculo de humedad
AJUSTE
	movlw d'1'
	addwf Auxiliar
return 
;-----------------------------------;Subrutina de ajuste general
AJUSTE_HUM							;1023 - Muestra = Ajuste en porcentaje real
	movlw 0x04
	movwf Arit_Operando_2H
	movlw 0x00
	movwf Arit_Operando_2L
									;Guardamos primero el 1024
	movf  HUMFH,0
	movwf Arit_Operando_1H
	movf  HUMFL,0
	movwf Arit_Operando_1L			;Guardamos nuestra muestra de temperatura en OPERANDO 1
	call Arit_Resta_16Bit			;OPERANDO2 - OPERANDO1 
RESULTADO							;De acuerdo a la libreria, el resultado se guarda en OPERANDO 2
	movf Arit_Operando_2H,0
	movwf RESH
	movf Arit_Operando_2L,0
	movwf RESL
return
;-----------------------------------;Subrutina de logica - humedad
CONVERSION_ADC
	bsf		ADCON0,GO_DONE	;Comienza la conversion
	btfsc	ADCON0,GO_DONE	;GO_DONE = 0 - Termina conversion y salta
	GOTO		$-1			;Siempre y cuando no acabe, regresamos
return
;------------------------------------;Subrutina para inicio de conversion ADC
Mensajes 
		addwf PCL,F
	M0
		DT "Temp: ", 0x00
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
LIMPIAR_PWM
	clrf  CCPR1L
	clrf  CCP1CON
	clrf  PR2
	clrw
	bcf BOMBITA
	return
;-----------------------------------;Subrutina de limpieza para PWM
LIMPIEZA_ADC
	clrf ADRESH
	bsf STATUS,RP0
	clrf ADRESL
	bcf STATUS,RP0
return
;-----------------------------------;Subrutina de limpieza ADRES
DESBORDAMIENTO	
		btfss PIR1,TMR2IF   ;Esperar desbordamiento	
		goto DESBORDAMIENTO
		bcf PIR1,TMR2IF		;Limpia el flag de desbordamiento del TMR1
		clrf TMR2
		GOTO INICIO
;-----------------------------------;Subrutina de desbordamiento
	INCLUDE	<ARIT.INC>
	INCLUDE <BIN_BCD.INC>			;Para mandar constantes al LCD, debemos convertir a BCD
	INCLUDE <LCD_MENS.INC>			
	INCLUDE <LCD_4BIT_16F877_D_E.INC>
	INCLUDE <RETARDOS.INC> 
;-----------------------------------;Librerias
END