rotbrute: rotbrute.o
	ld rotbrute.o -o rotbrute
rotbrute.o: rotbrute.nasm
	nasm -felf64 rotbrute.nasm -g -F dwarf
