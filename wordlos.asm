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
    mov ah, 0x67
    mov bp, title_string
    mov cx, 62
    call print_string

main_loop:
    call draw_board

check_input:
    mov ah, 0                       ; get keystroke
    int 0x16                        ; bios service to get input

    cmp ah, 0x1                     ; escape key
    jne check_input
    jmp exit

exit:
    int 0x20                        ; exit


;;; GAME FUNCTIONS

    ;
    ; Draws the board with the current game state
draw_board:


;;; BASE LIBRARY
%include "lib.asm"


;;; GAME GLOBAL VARIABLES
game_state:         db 0            ; current word : current letter
game_words:
    db "     "
    db "     "
    db "     "
    db "     "
    db "     "
    db "     "

;;; GAME CONSTANTS

title_string:       db "WORDLOS",0

%include "words.asm"
