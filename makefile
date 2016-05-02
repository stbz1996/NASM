Exec: objeto.o
	ld -o Exec objeto.o
	
objeto.o: pruebavers1.asm
	nasm -f elf64 -o objeto.o pruebavers1.asm
