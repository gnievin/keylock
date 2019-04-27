; Shift toggler
; Copyright (C) 1986 by Garrett P. Nievin
; 
; LARK'S VOMIT
; Code marked with an asterisk next to the comment semicolon is Sperry PC 
; unique.  Do not attempt to run on a non-Sperry computer without removing
; those lines.

code	segment para public 'code'

	assume cs:code,ds:nothing,es:nothing
	org	0100h

start	proc	far

begcode:
	jmp	implant		; jump around interrupt handler code

begres:		; area to remain core resident

rescode proc			; keystroke causes jump to here

	jmp	over		; jump over memory signature
	db	'stGN'		; program signature in memory
over:
	sti			; allow interrupts
	push	ax		; save that register
	in	al,60h		; get keyboard scan code
	cmp	al,36h		; right shift?
	je	rshift		; yes, go hanlit
	cmp	al,0b6h		; release of right shift key?
	jne	normal		; nope, go continue with old interrupt
	cmp	cs:shiftsw,1	; is shift already on?
	jne	shftstrt	; no, go turn it on and lose release scancode
	mov	cs:shiftsw,0	; clear shift on flag
	in	al,61h		;*get 8255 portB
	and	al,0F7h		;*turn off LED bit
	out	61h,al		;*and out to 8255 to turn off LED
	jmp	normal		; pass on shift release scan code

rshift:		; right shift key hit 
	cmp	cs:shiftsw,1	; was shift on?
	je	abnorm		; yes, don't pass on another shift-on code
	jmp	normal		; no, pass shift-on scan code
shftstrt:	; right shift key released after toggling shift on
	mov	cs:shiftsw,1	; set shift on flag
	in	al,61h		;*get 8255 portB
	or	al,8		;*turn on LED bit
	out	61h,al		;*and out it to 8255 to turn on LED
abnorm:		; abnormal handling of scan code.  to the bit bucket with it.
	in	al,61h		; get portB
	or	al,80h		; set acknowledge / clear keyboard bit
	out	61h,al		; and out it again
	and	al,7fh		; clear ack bit
	out	61h,al		; out that, enabling keyboard again
	cli			; no interruptions, Mrs. a-Whiggins
	mov	al,20h		; end-of-interrupt command
	out	20h,al		; send it to the 8259
	pop	ax		; restore register
	sti			; interruptable again
	iret			; quit without performing normal interrupt
normal:		; key other than right shift, or passing on rshift scan codes
	pop	ax		; restore that register
	jmp	dword ptr cs:oldint9	; goto old int9 handler

oldint9 dw	0,0		; doubleword value of old int9 vector
shiftsw	db	0		; shift on/off flag


rescode	endp

endres:		; end of core res area

reslen	equ	endres - begres		; length of new resident code
strtres	equ	begres - begcode + 100h	; start of resident code
psplen	equ	5ch			; length of necessary PSP

implant:	; code to put new int 9 front end in core
	mov	ax,3509h	; get int vector function
	int	21h		; get vector of interrupt 9 handler
	cmp	es:[bx+3],'ts'	; already loaded?
	jne	fresh		; nope, go install
	cmp	es:[bx+5],'NG'  ; make sure
	jne	fresh		; naaah, go install
	lea	dx,cs:stalemsg	; DX points to already installed message
	mov	ah,09h		; DOS display string func	
	int	21h		; go display message
	int	20h		; and quit
	
fresh:
	in	al,61h		;*get 8255 portB
	and	al,0F7h		;*turn off LED bit
	out	61h,al		;*and turn off LED
	lea	dx,cs:instlmsg	; DX points to installation message 
	mov	ah,09h		; display string function
	int	21h		; give the user the poop
	mov	ax,3509h	; get int vector function
	int	21h		; get vector of old interrupt 9 handler
	mov	oldint9,bx	; int location in ES:BX, save it
	mov	oldint9+2,es	; "
	mov	ax,2509h	; set new interrupt 9 vector to me
	mov	dx,offset rescode	; address of which is in DX
	int	21h		; go do it
	push	cs		; DS and ES both end
	pop	es		; up pointing at
	push	cs		; code area
	pop	ds		; "
	mov	di,psplen	; where program will end up
	mov	si,strtres	; start of resident code
	mov	cx,reslen	; amount of resident code to move
	cld			; go forward in move
	rep movsb		; move code back in mem
	mov	dx,psplen + reslen	; DX pointing to next free paragraph
	mov	ax,3100h	; keep, return code of 0
	int	21h		; terminate

stalemsg db	'Shift toggle is already installed and active!',07,07,13,10,10,10
instlmsg db	'ีออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออธ' 
	db	13,10
	db	'ณ  Shift toggle        by        Garrett Nievin                          ณ'
	db	13,10
	db	'ณ The right hand shift key is now a shift function toggle, alternating   ณ'
	db	13,10
	db	'ณ between a shifted and non-shifted condition, and the power LED on the  ณ'
	db	13,10
	db	'ณ system unit displays the current toggle on/off status.                 ณ'
	db	13,10
	db	'ิออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออพ'
	db	13,10
	db	'$'
		
start	endp
code	ends
	end	start
