The input language will be familiar to anyone who knows C. A program consists of "statements", which are constructs of one of the following forms:
* A sequence of statements surrounded by {}. This runs each statement sequentially
* An expression, followed by a semicolon. This evaluates the expression.
* A declaration of the form <type> <varname> = <value>, followed by a semicolon. This creates a variable called <varname> of type <type> and initializes it to <value>.
* if (expression) statement
* if (expression) statement else statement
* while(expression) statement
* for (statement expression; expression) statement
* A single semicolon, which does nothing.
* The keyword break, which will exit the current loop
* The keyword continue, which will start the next iteration of the current loop
* Labels, which are identifiers followed by :.
* The keyword goto followed by a label name, which will immediately go to the label.
"Expressions" can be formed using the operators listed below, character literals (a character surrounded by ''), integer literals, and variable names.
* x + y is the sum of x and y.
* x - y is the difference between x and y.
* x * y is the product of x and y.
* x / y is the quotient of x divided by y.
* x % y is the remainder of x divided by y.
* x >> y shifts x left by y places.
* x << y shifts x right by y places.
* x & y is a bitwise AND.
* x | y is a bitwise OR.
* x ^ y is a bitwise XOR.
* x && y is a logical AND.
* x || y is a logical OR.
* x == y determines if x equals y.
* x != y determines if x is not equal to y.
* x > y, x < y, x >= y and x <= y work similarly.
* x = y sets the variable or memory location named by x to y.
* x++ increments x and evaluates to the old value.
* x-- decrements x and evaluates to the old value.
* ++x and --x work similarly but return the new value.
* ~x is the bitwise NOT of x.
* !x is the logical NOT of x.
* -x is the additive inverse (the negative) of x.
* +x is the same as x.
* (typename) x "casts" (converts without changing the value of) x to the new type.
* \*x returns the value at memory location x.
* &x returns the memory location of x.
* x ? y : z returns y if x is nonzero and z otherwise.
The following types exist:
* int is a 4 byte integer.
* char is a 1 byte character.
* short is a 2 byte integer.
* int\*, char\*, and short\* are all "pointers" to types - they contain a memory location.
Strings can be represented using the string literal format in initializers.
