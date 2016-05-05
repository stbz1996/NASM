html-xml: html-xml.o
	ld -o html-xml html-xml.o
	
html-xml.o: html-xml.asm
	nasm -f elf64 -o html-xml.o html-xml.asm
