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
    mov cx, [game_state_letter]            ; get current state (word:letter)
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

    cmp al, 0x08                    ; 0x08 - backspace
    je del_letter  

    cmp al, 0x0d                    ; 0x0d - Enter
    je confirm_word                 ; for now, just loop

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
    add al, 0x20                    ; makes it lower case
add_letter:
    mov cl, byte [game_state_letter]
    cmp cl, 5
    je main_loop

    push ax

    mov ax, [game_state_letter]     ; copies the letter and the word
    mov byte [game_w], ah
    mov byte [game_l], al
    xor ax, ax                      ; resetting AX
    mov al, 5                       ; 5 letter per word
    mov bl, byte [game_w]           ; get current word
    mul bl                          ; multiply by the amount of words
    add al, byte [game_l]           ; adding the current letter
    mov bx, game_words              ; getting pointer to word list
    add ax, bx                      ; adding pointer to offset
    mov bp, ax                      ; setting to bp

    pop ax
    mov byte [bp], al
    mov al, byte [game_l]
    inc al
    mov ah, byte [game_w]
    mov byte [game_state_letter], al
    mov byte [game_state_word], ah

    jmp main_loop

del_letter:
    mov al, byte [game_state_letter]
    cmp al, 0                       ; if it's already the first letter, skip
    je main_loop

    mov ax, [game_state_letter]
    mov byte [game_w], ah
    mov byte [game_l], al
    xor ax, ax                      ; resetting AX
    mov al, 5                       ; 5 letter per word
    mov bl, byte [game_w]           ; get current word
    mul bl                          ; multiply by the amount of words
    add al, byte [game_l]           ; adding the current letter
    mov bx, game_words              ; getting pointer to word list
    add ax, bx                      ; adding pointer to offset
    dec ax
    mov bp, ax                      ; setting to bp
    
    mov byte [bp], 0x20             ; setting space, "empty letter"
    
    mov al, byte [game_state_letter]
    dec al                          ; go back to the previous position
    mov byte [game_state_letter], al

    jmp main_loop

confirm_word:
    mov al, byte [game_state_letter]
    cmp al, 5                       ; comparing if it's in the last letter
    jne check_input

    ; 1) compare if it's in the word list
    call check_valid_word
    cmp ah, 0                       ; if ah == 0, then word is valid
    jne check_input                        ; TODO: display an error here

    ; 2) compare with the selected word and set state

    ; 3) increment word
    mov al, byte [game_state_word]
    inc al
    mov byte [game_state_word], al
    mov byte [game_state_letter], 0

    jmp main_loop

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

    ; pointer to the letter in board
    ; used for both letter data and state
    push bx
    xor ax, ax                      ; resetting AX
    mov al, 5                       ; 5 letter per word
    mov bl, byte [game_w]           ; get current word
    dec bl                          ; bl -= 1
    mul bl                          ; multiply by the amount of words
    add al, byte [game_l]           ; adding the current letter
    dec al                          ; al -= 1
    mov [game_letter_ptr], ax       ; saving it to the pointer variable

    mov bx, game_words_state        ; getting pointer to the word/letters state
    add ax, bx                      ; adding pointer to offset
    mov bp, ax                      ; setting bp to the pointer
    xor ax, ax                      ; resetting ax
    mov ah, byte [bp]               ; getting the state data
    mov byte [game_letter_selected_color], ah
    pop bx

    push ax                         ; pushing the state as a color to the box function
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
    add sp, 8                       ; returns the stack pointer, same as pop 4 times

    ; Print current letter
    mov ax, [game_letter_ptr]
    mov bx, game_words              ; getting pointer to word list
    add ax, bx                      ; adding pointer to offset
    mov bp, ax                      ; setting to bp

    mov ah, byte [game_letter_selected_color] ; setting the current state color
    mov al, byte [bp]               ; copying the character on the table to AL
    sub al, 0x20
    mov di, [game_pos]              ; adding the cursor position offset to DI
    mov [es:di], ax                 ; setting the current char in AX to video memory

    pop bx
    pop cx
    ret

    ;
    ; Check if the input word is in the list of words
    ; Return:   AH - 0 if word is valid
    ;
check_valid_word:
    mov cx, [word_count]            ; copy the amount of words

_check_valid_word_init:
    ; 1) get pointer to the current word
    xor ax, ax                      ; resetting AX
    mov al, 5                       ; 5 letter per word
    mov bl, byte [game_state_word]  ; get current word
    mul bl                          ; multiply by the amount of words
    add ax, game_words              ; ; adding the offset to the address
    mov [general_ptr1], ax          ; saving it to the pointer variable

    ; 2) get pointer to current word in list
    mov ax, 5                       ; 5 letter per word
    mov bx, cx
    dec bx
    mul bx                          ; multiply by the amount of words
    add ax, word_list               ; adding the offset to the address
    mov [general_ptr2], ax          ; saving it to the pointer variable

    ; 3) in order to compare letter by letter, you must
    push cx

    mov cx, 5                       ; 5 letters
_check_equal_letter:
    mov ax, [general_ptr1]          ; copy address of the first pointer
    add ax, cx                      ; adding current letter offset
    dec ax
    mov bp, ax
    xor ax, ax
    mov al, byte [bp]               ; get letter value
    push ax                         ; store letter from pointer 1

    mov ax, [general_ptr2]          ; copy address of the second pointer
    add ax, cx                      ; adding current letter offset
    dec ax
    mov bp, ax
    pop ax                          ; restore previous letter value
    mov ah, byte [bp]               ; get letter value

    cmp ah, al

    jne _check_equal_letter_continue
    loop _check_equal_letter        ; loop letters    
    ; ... if it got here, all words are the same, so it's good
    pop cx
    mov ah, 0
    ret
_check_equal_letter_continue:
    pop cx
    loop _check_valid_word_init     ; loop words
    ; ... if it got here, there are no similar words
    mov ah, 1
    ret


;;; BASE LIBRARY
%include "lib.asm"


;;; GAME GLOBAL VARIABLES
game_selected_world:        dw 0            ; pointer to the selected word in the list
game_state_letter:          db 0            ; current letter
game_state_word:            db 0            ; current word
game_words:
    db "     "
    db "     "
    db "     "
    db "     "
    db "     "
    db "     "

; the state is the color of the background:
;   - 0x78: empty
;   - 0x87: letter not in word
;   - 0xE0: letter in word
;   - 0x2F: letter in correct position
game_words_state:
    db 0x78,0x78,0x78,0x78,0x78
    db 0x78,0x78,0x78,0x78,0x78
    db 0x78,0x78,0x78,0x78,0x78
    db 0x78,0x78,0x78,0x78,0x78
    db 0x78,0x78,0x78,0x78,0x78
    db 0x78,0x78,0x78,0x78,0x78

game_w:                     db 0            ; current word used in functions
game_l:                     db 0            ; current letter used in functions
game_pos:                   dw 0            ; current position used in functions
game_letter_ptr:            dw 0            ; pointer for the ltter in general
game_letter_selected_color: db 0            ;   ... selected state

general_ptr1:                dw 0            ; just general pointer
general_ptr2:                dw 0            ; just general pointer


;;; GAME CONSTANTS

title_string:       db "WORDLOS",0

%include "words.asm"
