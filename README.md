This project is a compiler for a very basic C-like language (referred to internally as C--).
It outputs "machine agnostic assembly" (more in implementation.)
In order to compile this for your machine, type `dub build`.
Then, run it using `./compiler <input> <output>`. This will read a program from the input and output assembly instructions to the output.
This compiler is written in the D programming language and as such requires a suitable compiler as well as the D package manager, `dub`.
For more specific information, visit one of the following files:
* implementation.md for details on what the output format is,
* cmm.md for details on the input language, or
* debug.md for debugging error messages.
