all: dos

dos:
	nasm -f bin -o wordlos.com wordlos.asm

clear:
	rm wordlos.com
