# ROT13Brute
ROT13 brute forcer made in x64 assembly

This is my implementation of a ROT13 bruteforcer.

This is not the best way to implement this, it's just the simplest way I found (which doesn't mean it's the simplest one)

## Assembling and liniking

```
$ nasm -felf64 rotbrute.nasm -g -F dwarf
$ ld rotbrute.o -o rotbrute
```

## Usage
`$ ./rotbrute <filename>`

`$ echo -n "encoded string" | ./rotbrute`

Note that echoing without the "-n" will cause the newline (0xA) to be double printed.

The same will happen if there is a newline at the end of the file.

## Screenshot
![image](https://user-images.githubusercontent.com/3837916/129993286-4b37dc97-2cc6-4237-8783-29810f4afe7d.png)

## TODO

Print line numbers
