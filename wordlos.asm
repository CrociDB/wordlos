    org 0x0100

; Set 80-25 text mode
    mov ax, 0x0002
    int 0x10

    mov ax, 0xb800                  ; Segment for the video data
    mov es, ax

    cld

;;; GAME FLOW

start:
    ; Game title
    mov ah, 0x07
    mov bp, title_string
    mov cx, 72
    call print_string

main_loop:
    call draw_board

    ; Setting the cursor to the right position
    mov cx, [game_state]            ; get current state (word:letter)
    mov al, 4
    mul cl
    add al, 31
    mov dl, al                      ; set current column

    mov al, 2
    mul ch
    add al, 4
    mov dh, al                      ; set current line


    mov ah, 02h                     ;Set cursor position function
    mov bh, 0                       ;Page number
    int 10h                         ;Interrupt call

check_input:
    mov ah, 0                       ; get keystroke
    int 0x16                        ; bios service to get input

    cmp al, 0x0d                    ; 0x - Enter
    je check_input                  ; for now, just loop

    cmp al, 0x1b	                ; escape key
    je exit

    ; Check if it's within the character range and check case
    ; A-Z: 0x41-0x5A
    ; a-z: 0x61-0x7A

    cmp al, 0x41
    jl check_input                  ; less than `A`
    cmp al, 0x7a
    jg check_input                  ; greater than `z`

    cmp al, 0x61
    jge add_letter                  ; it means it's already in range a-z

    cmp al, 0x5a
    jle lower_add_letter            ; it's within A-Z, needs lower case

    jmp check_input

lower_add_letter:
    sub al, 0x20                    ; makes it lower case
add_letter:
    jmp check_input


exit:
    int 0x20                        ; exit


;;; GAME FUNCTIONS

    ;
    ; Draws the board with the current game state
    ; go word by word and print the data
    ;5
draw_board:
    mov cx, 6                       ; 6 words
_print_word:
    call print_word
    loop _print_word
    ret

    ;
    ; Print one word
    ; Params:   cx - current word
    ;
print_word:
    mov bx, cx                      ; save current word
    push cx
    mov cx, 5                       ; 5 letters
_print_letter:
    call print_letter
    loop _print_letter
    pop cx
    ret

    ;
    ; Prints one letter
    ; Params:   cx - current letter
    ;           bx - current word
    ;
print_letter:
    mov byte [game_l], cl
    mov byte [game_w], bl

    push cx                         ; draw_box function will change CX and BX, so we keep it
    push bx

    push 0x7800                     ; color
    push 0x0103                     ; box dimensions 

    mov ax, 8
    mul cx
    add ax, 52
    push ax
    mov [game_pos], ax              ; saving current column to be used later

    mov ax, 160 * 2
    mul bx
    add ax, 160 * 2
    push ax                         ; vertical position
    
    add ax, [game_pos]              ; adding column to line to use later
    add ax, 2                       ; ONE character offset, middle of the box
    mov [game_pos], ax              ; saving current cursor position


    call draw_box
    add sp, 8

    ; Print current letter
    xor ax, ax                      ; resetting AX
    mov al, 5                       ; 5 letter per word
    mov bl, byte [game_w]           ; get current word
    dec bl                          ; bl -= 1
    mul bl                          ; multiply by the amount of words
    add al, byte [game_l]           ; adding the current letter
    dec al                          ; al -= 1
    mov bx, game_words              ; getting pointer to word list
    add ax, bx                      ; adding pointer to offset
    mov bp, ax                      ; setting to bp

    mov ah, 0x78                    ; for now setting the color by hand
    mov al, byte [bp]               ; copying the character on the table to AL
    mov di, [game_pos]              ; adding the cursor position offset to DI
    mov [es:di], ax                 ; setting the current char in AX to video memory

    pop bx
    pop cx
    ret


;;; BASE LIBRARY
%include "lib.asm"


;;; GAME GLOBAL VARIABLES
game_state:         dw 0            ; current word : current letter
game_words:
    db "TESTZ"
    db "ABCDE"
    db "ZY   "
    db "     "
    db "     "
    db "     "

game_w:             db 0            ; current word used in functions
game_l:             db 0            ; current letter used in functions
game_pos:           dw 0            ; current position used in functions

;;; GAME CONSTANTS

title_string:       db "WORDLOS",0

%include "words.asm"
