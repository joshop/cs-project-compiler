A section from the source code will be hugely helpful in understanding the output format:
```
This compiler outputs Machine Agnostic Assembly. This is a basic assembly-like intermediate language where all lines should ideally compile to one or two machine instructions.
Each line consists of an operator, a right side operand and a left side operand (for binary operations only).
The operands can be integers in any base, labels or temps. Temps are values that would ideally be stored in registers, represented with a $ followed by an integer.
In a system with, say, 4 general purpose registers, $0, $1, $2 and $3 would be stored in these while $4 and onward would be stored somewhere else.
Most code should attempt to use at most 4 temps and use labels as much as possible.
The assignment and compound assignment operators exist and work as expected; however, *=, /=, %= and sometimes others may not be implemented in hardware. For example, on an x86_64 machine,
$1 &= $0
performs an AND rbx, rax.
Some other operators exist; notably, the read operator (MOV lside, [rside]) and the write operator (MOV [rside], lside). 
The read and write operators must be followed by an underscore and a bitwidth, which specifies the number of bytes to be read or written. Alternatively, addr will equal the CPU bitwidth.
There are also unary operators. The -, ~, !, ++ and -- unary operators exist, as well as push and pop, which manipulate the stack.
The data operator must take an integer literal and writes it directly to the output..
Labels are specified with a colon following them and act as they do in traditional assembly.
If an integer is written to, the value will be written to that address.
There are also test and jump operators. jmp will work to jump and call and ret will work as expected. The test operation performs a test and sets flags for jumps; use jmpi for a conditional jump.
The test operation is formed by typing test and then one of (==, !=, &&, ||, <, >, <=, >=).
You can also type test as a unary operator to get the test result. For example:
$1 test> $0
test $0
sets $0 to 1 if $1 is greater than $0 and sets $0 to 0 otherwise.
The addr operator works like data but operates on the addressing size of the current processor. For example, on an x86_64 machine,
addr 0
acts like 8 data 0 operations, but on a 32-bit system it acts like 4 data 0 operations.
Finally, end marks the end of a program.
```
Obviously, there is no machine that runs this assembly code, but it is *similar* enough to modern assembly languages that it can be easily converted to almost any of them.
The source code also contains some sections describing the structure of certain constructs like if or while.
