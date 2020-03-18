If you're using this compiler to write a program, you will encounter error messages which you do not understand. Below is a list of these error messages and examples.
* `Usage: ./compiler <input file> <output file>`  
You didn't supply the command line arguments to the compiler.
* `Conflicting types for assignment: <type> = <type>`  
You tried to assign one type to another. An example of this:  
```  
char x;  
int* y = x;  
```
* `Type <type> is not a pointer.`  
You tried to dereference something that wasn't a pointer. Example:  
```  
char x = 5;  
char y = *x;  
```
* `Variable <var> is not defined.`  
Pretty self explanatory; you didn't declare the variable. Example:  
```  
int myvariable = 10;  
int othervariable = myvarriable;  
```
* `This is not a variable!`  
You tried to assign to something that, as the error message is enthusiastically telling you, is not a variable. Example:
```  
5 = 6;  
```
* `Invalid types: <type> <op> <type>.`  
You tried to perform the binary operator on two incompatible types. Example:  
```  
int* x;  
int* y;  
x + y;  
```
If you ever encounter an "assertion failed" message or a range violation or other error from the D runtime, this is not due to a bug in your code. This is due to a bug in the *compiler* and you should contact me.
