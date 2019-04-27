; KeyLock program
; changes "hold&hit" keys like shift and ctrl to toggles like caps lock
; should run on any MSDOS machine with same keyboard scan codes as Sperry PC
; (was going to name another PC but decided I don't like them that well).
;
; Please send me any suggestions or program modifications - it's for a good
; cause.  I can be reached on the Telstar BBS in San Antonio, TX or at:
;
; Garrett Nievin
; 4518 Valley Brook Dr.
; San Antonio, TX 78238
; 
; Thanks.

code	segment para public 'code'
	assume cs:code,ds:code,es:code
	org	0100h
start	proc	far

; equates here - ports, scan codes, # of keys to check, and constants
numkeys	equ	3			; number of keys handled by program
alt	equ	38h			; scan code for alt
ctrl	equ	1dh			; scan code for control
lshift	equ	2ah			; scan code for left shift
portA	equ	60h			; 8255A port A, usually keybd scan code
portB	equ	61h			; 8255A port B, various switches
release	equ	80h			; hi bit in scan code means key release 
hibiton	equ	80h			; hi bit in byte for or'ing in
hbitoff equ	7fh			; hi bit in byte for and'ing out
yes	equ	1			; Boolean true
no	equ	0			; Boolean false
lf	equ	10			; ASCII linefeed
cr	equ	13			; ASCII carriage return

begcode:	; beginning of code
	jmp	implant			; jump around interrupt handler code

begres:		; beginning of area to remain core resident
rescode proc	; keystroke causes jump to here
	jmp	startme			; awake/asleep gate
	jmp	dword ptr cs:oldint9	; goto old int9 handler
memsig	db	'klGN'			; program signature in memory

startme:	; my normal keyboard processing begins here
	sti				; allow interrupts
	cld				; string ops move forward
	push	ax			; save registers - accumulator
	push	bx			; " used by DOS interrupt
	push	cx			; " used as loop counter
	push	di			; " used as loop data pointer
	push	ds			; " data segment cover reg
	push	es			; " extra seg & used by DOS interrupt
	push	cs			; data seg same as code seg
	pop	ds			; "
	push	cs			; extra seg in code seg also 
	pop	es			; "
	in	al,portA		; get keyboard scan code
	mov	ah,al			; save code into AH
	and	al,hbitoff		; and lose top bit
	mov	cx,numkeys+1		; get # of keys to search thru
	lea	di,scancodes		; point search area at scan codes
	repne scasb			; look for scan code in table
	jcxz	passcan			; no find -  not special scan code
	sub	di,numkeys+1		; di now is index into tables
	mov	al,ah			; restore old scan code
	test	al,release		; was it a release of a key?
	jnz	relkey			; yes, go to turn-lock-off routine
	cmp	byte ptr [di],yes	; was keylock on?
	jz	losescan		; yes, don't pass on key-on code
	jmp	passcan			; go to normal-key routine

relkey:		; release of a special key
	cmp	byte ptr [di],yes	; is keylock already on?
	jnz	lockstrt		; no, go to turn-lock-on routine
	mov	byte ptr [di],no	; clear keylock flag
	jmp	passcan			; pass on release scancode

lockstrt:	; right shift key released after toggling shift on
	mov	byte ptr [di],yes	; set appropriate lock flag

losescan:	; abnormal handling of scan code.  to the bit bucket with it.
	in	al,portB		; get portB
	or	al,hibiton		; set acknowledge / clear keyboard bit
	out	portB,al		; and out it again
	and	al,hbitoff		; clear ack bit
	out	portB,al		; out that, enabling keyboard again
	pop	es			; restore regs
	pop	ds			; "
	pop	di			; "
	pop	cx			; "
	pop	bx			; "
	cli				; no interrupts allowed here
	mov	al,20h			; end-of-interrupt command
	out	20h,al			; send it to the 8259
	sti				; interruptable again
	pop	ax			; restore last register
	iret				; quit w/o performing normal interrupt

passcan:	; normal handling of a keystroke.  pass on to old int handler
	pop	es			; restore regs
	pop	ds			; "
	pop	di			; "
	pop	cx			; "
	pop	bx			; "
	pop	ax			; "
	jmp	dword ptr cs:oldint9	; goto old int9 handler

oldint9 dw	0,0			; dword old int9 vector (es:bx)

; keyflag table must immediately precede scan code table.
keyflags db	numkeys dup (no)	; lock flag for each lockable key
scancodes db 	alt,ctrl,lshift		; table of lockable key scan codes

rescode	endp
endres:		; end of core res area

reslen	equ	endres - begres		; length of new resident code
strtres	equ	begres - begcode + 100h	; start of resident code
psplen	equ	5ch			; length of necessary PSP

implant:	; code to put new int 9 front end in core
	mov	ax,3509h		; "get interrupt vector" function
	int	21h			; get vector of interrupt 9 handler
	cmp	es:[bx+offset memsig-begres],'lk'  ; already loaded?
	jne	notin			; nope, go see if install time
	cmp	es:[bx+offset memsig-begres+2],'NG'  ; make sure
	jne	notin			; naaah, go see if install
	; could save a few bytes here by and'ing cs:81h to drop lc bit
	; cs:81h is start of command line in PSP
	cmp	cs:[81h],'s/'		; if /s option, go to sleep
	je	gosleep			; go do it
	cmp	cs:[81h],'S/'		; if /s option, go to sleep
	je	gosleep			; go do it
	cmp	cs:[81h],'w/'		; if /w option, wake up
	je	wakeup			; go do it
	cmp	cs:[81h],'W/'		; if /w option, wake up
	je	wakeup			; go do it
	cmp	cs:[81h],'i/'		; if /i option, too bad, already in
	je	stale			; go do it
	cmp	cs:[81h],'I/'		; if /i option, too bad, already in
	je	stale			; go do it
	jmp	notin			; go give help msg, as if not installed

notin:		; come here if install (/i option) or if no valid option given
	cmp	cs:[81h],'I/'		; if /i option, initial installation
	je	install			; go do it
	cmp	cs:[81h],'i/'		; if /i option, initial installation
	je	install			; go do it
	lea	dx,instrmsg		; DX points to message 
	jmp	outmsg			; go display message and quit

gosleep:	; come here if time to go to sleep (/s option)
	mov	word ptr es:[bx],9090h	; no-op out jump instruction
	lea	dx,sleepmsg		; DX points to message 
	jmp	outmsg			; go display message and quit

wakeup:		; come here if time to wake up (/w option)
	mov	word ptr es:[bx],0aebh ; put back jump instruction
	lea	dx,wakemsg		; DX points to message 
	jmp	outmsg			; go display message and quit

stale:		; come here if install chosen and already installed
	lea	dx,stalemsg		; DX points to message 
		; and fall into outmsg

outmsg:		; display message and terminate
	mov	ah,09h			; display string function
	int	21h			; give the user the poop
	int	20h			; and die, you gravy sucking pigs.
	
install:	; install program into interrupt table
	lea	dx,instlmsg		; dx points to installation message 
	mov	ah,09h			; display string function
	int	21h			; give the user the poop
	mov	oldint9,bx		; int location in es:bx, save it
	mov	oldint9+2,es		; "
	mov	ax,2509h		; "set new interrupt" function
	mov	dx,offset rescode	; address of which is in dx
	int	21h			; i now get int 9's
	push	cs			; ds and es both end
	pop	es			; up pointing at
	push	cs			; code area
	pop	ds			; "
	mov	di,psplen		; where program will end up
	mov	si,strtres		; start of resident code
	mov	cx,reslen		; amount of resident code to move
	cld				; go forward in move
	rep movsb			; move code back in mem
	mov	dx,psplen + reslen	; dx pointing to next free paragraph
	mov	ax,3100h		; "keep", return code of 0
	int	21h			; terminate and stay core resident

sleepmsg db     'KeyLock functions are now disabled.',cr,lf,'$'	
wakemsg	 db	'KeyLock functions are now re-enabled.',cr,lf,'$'
stalemsg db	'KeyLock has already been installed!',cr,lf,'$'
instlmsg db	'KeyLock is now installed and functioning.',cr,lf,'$'

instrmsg db	'ีออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออธ',cr,lf 
	db	'ณ                                                                      ณ',cr,lf
	db	'ณ   KeyLock     Copyright (C) 1986 by Garrett P. Nievin                ณ',cr,lf
	db	'ณ                                                                      ณ',cr,lf
	db	'ณ     KeyLock turns keys which are normally held while another key     ณ',cr,lf
	db	'ณ     is pressed (e.g. shift, control, alt) into locking-state keys    ณ',cr,lf
	db	'ณ     like number lock or caps lock.  Keys currently supported are:    ณ',cr,lf
	db	'ณ     alt, ctrl, and the left shift key.  The right shift key          ณ',cr,lf
	db	'ณ     continues to work as normal.                                     ณ',cr,lf
	db	'ณ                                                                      ณ',cr,lf
	db	'ณ   usage:                                                             ณ',cr,lf
	db	'ณ        Keylock/I.......Install KeyLock                              ณ',cr,lf
	db	'ณ        Keylock/S.......Suspend KeyLock functions                    ณ',cr,lf
	db	'ณ        Keylock/W.......Wake KeyLock back up from suspended state    ณ',cr,lf
	db	'ณ         Any invalid option will display this message.                ณ',cr,lf
	db	'ณ         Note: no space between program name and slash!                                                             ณ',cr,lf
	db	'ณ                                                                      ณ',cr,lf
	db	'ิออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออพ',cr,lf
	db	'$'

start	endp
code	ends
	end	start
