import pegged.grammar;
import std.range : chunks;
import std.stdio: writeln, writefln;
import std.conv: to;
import std.algorithm.searching: canFind, endsWith, count;
import std.algorithm.mutation: remove;
import core.stdc.stdlib: exit;


enum string name = "CMinusMinus";
// Construct the grammar for C--
mixin(grammar(name ~ `:
Start < Statement
IntegerLiteral < ~([0-9]+)
CharLiteral <- "'" . "'"
StringLiteral <- '\"' ~(((!'\"' .) | :'\\' '\"')*) !'\\' '\"'
Variable < ~(identifier)
AddrVariable < ~(identifier)
Dereference < '&'
Type < ~(Type '*' / 'int' / 'char' / 'short')
IncDec < '++' / '--'
Statement < ';' / StatementDeclare ';' / Expression ';' / StatementBlock / StatementIf / StatementWhile
StatementBlock < '{' Statement* '}'
StatementDeclare < Type Variable ('=' Expression)?
StatementIf < 'if' '(' Expression ')' Statement
StatementWhile < 'while' '(' Expression ')' Statement
Sizeof < 'sizeof' '('? (Type / Variable) ')'?
ExpressionAtom < Sizeof / '(' Expression ')' / IntegerLiteral / CharLiteral / StringLiteral / Variable
ExpressionUnaryPost < ExpressionAssignLeft IncDec / ExpressionAtom
ExpressionUnaryPreRep < !'--' '-' / !'++' '+' / '~' / '!' / '*' / ~('(' Type ')')
ExpressionUnaryPre < IncDec ExpressionAssignLeft / ExpressionUnaryPreRep* (ExpressionUnaryPost / Dereference* ExpressionAssignLeft)
ExpressionProdRep < ('*' / '/' / '%') ExpressionUnaryPre
ExpressionProd < ExpressionUnaryPre ExpressionProdRep*
ExpressionSumRep < (!'++' '+' / !'--' '-') ExpressionProd
ExpressionSum < ExpressionProd ExpressionSumRep*
ExpressionShiftRep < ('<<' / '>>') ExpressionSum
ExpressionShift < ExpressionSum ExpressionShiftRep*
ExpressionCmpRep < ('<=' / '>=' / '<' / '>') ExpressionShift
ExpressionCmp < ExpressionShift ExpressionCmpRep*
ExpressionEqRep < ('==' / '!=') ExpressionCmp
ExpressionEq < ExpressionCmp ExpressionEqRep*
ExpressionBitAndRep < !'&&' '&' ExpressionEq
ExpressionBitAnd < ExpressionEq ExpressionBitAndRep*
ExpressionBitXorRep < '^' ExpressionBitAnd
ExpressionBitXor < ExpressionBitAnd ExpressionBitXorRep*
ExpressionBitOrRep < !'||' '|' ExpressionBitXor
ExpressionBitOr < ExpressionBitXor ExpressionBitOrRep*
ExpressionLogAndRep < '&&' ExpressionBitOr
ExpressionLogAnd < ExpressionBitOr ExpressionLogAndRep*
ExpressionLogOrRep < '||' ExpressionLogAnd
ExpressionLogOr < ExpressionLogAnd ExpressionLogOrRep*
ExpressionTernary < ExpressionLogOr ('?' ExpressionLogOr ':' ExpressionLogOr)?
ExpressionAssign < !'==' ('=' / '+=' / '-=' / '*=' / '/=' / '%=' / '<<=' / '>>=' / '&=' / '|=' / '^=')
Expression < (ExpressionAssignLeft ExpressionAssign)? ExpressionTernary
ExpressionAssignLeftParens < '*' ExpressionTernary / '(' ExpressionAssignLeftParens ')'
ExpressionAssignLeft < AddrVariable / ExpressionAssignLeftParens
`));

/*
 * This compiler outputs Machine Agnostic Assembly. This is a basic assembly-like intermediate language where all lines should ideally compile to one or two machine instructions.
 * Each line consists of an operator, a right side operand and a left side operand (for binary operations only).
 * The operands can be integers in any base, labels or temps. Temps are values that would ideally be stored in registers, represented with a $ followed by an integer.
 * In a system with, say, 4 general purpose registers, $0, $1, $2 and $3 would be stored in these while $4 and onward would be stored somewhere else.
 * Most code should attempt to use at most 4 temps and use labels as much as possible.
 * The assignment and compound assignment operators exist and work as expected; however, *=, /=, %= and sometimes others may not be implemented in hardware. For example, on an x86_64 machine,
 * $1 &= $0
 * performs an AND rbx, rax.
 * Some other operators exist; notably, the read operator (MOV lside, [rside]) and the write operator (MOV [rside], lside). 
 * The read and write operators must be followed by an underscore and a bitwidth, which specifies the number of bytes to be read or written. Alternatively, addr will equal the CPU bitwidth.
 * There are also unary operators. The -, ~, !, ++ and -- unary operators exist, as well as push and pop, which manipulate the stack.
 * The data operator must take an integer literal and writes it directly to the output..
 * Labels are specified with a colon following them and act as they do in traditional assembly.
 * If an integer is written to, the value will be written to that address.
 * There are also test and jump operators. jmp will work to jump and call and ret will work as expected. The test operation performs a test and sets flags for jumps; use jmpi for a conditional jump.
 * The test operation is formed by typing test and then one of (==, !=, &&, ||, <, >, <=, >=).
 * You can also type test as a unary operator to get the test result. For example:
 * $1 test> $0
 * test $0
 * sets $0 to 1 if $1 is greater than $0 and sets $0 to 0 otherwise.
 * The addr operator works like data but operates on the addressing size of the current processor. For example, on an x86_64 machine,
 * addr 0
 * acts like 8 data 0 operations, but on a 32-bit system it acts like 4 data 0 operations.
 * Finally, end marks the end of a program.
 */


string[][string] variables;
enum string[string] bitwidth = ["int": "4", "int*": "addr", "char": "1", "char*": "addr", "short": "2", "short*": "addr"]; // stores the sizes of various data types
void main() {
	/*writeln(compile("{
			char *mystring = \"how NOW bRown COw\";
			char tmp;
			while (*mystring) {
				tmp = *mystring;
				if (tmp >= 'a' && tmp <= 'z') *mystring -= ' ';
				if (tmp >= 'A' && tmp <= 'Z') *mystring += ' ';
				mystring++;
			}
			}"));*/
	variables["chars"] = ["char*"];
	variables["mystring"] = ["char*"];
	writeln(compile(`*(chars)++;`));
}

string[] compile(string code) {
	auto tree = CMinusMinus(code); // create parse tree
	writeln(tree);
	string[][] stack; // stack stores values in the format [varname, type, addr]; varname is bound variable name, addr is "yes" or "no" - if it represents variable address.
	string[] instructions; // list of output instructions, one per entry/line
	int labelNum = 0; // number of consumed labels, used for label naming
	int[][] temps; // temporary values like string constants
	void parseExpression(ParseTree p) {
		bool addrVariable = false; // addrVariable is whether the value is the address of a variable instead of its value
		switch (p.name) {
			case name ~ ".Statement":
				if (p.children.length > 0) {
					assert(p.children.length == 1);
					parseExpression(p.children[0]); // just parse the child if it's not a null statement
					if (p.children[0].name == name ~ ".Expression") {
						stack = stack.remove(stack.length-1); // pop stack because expression doesn't clean up after itself
					}
				}
				return;	
			case name ~ ".StatementDeclare":
				assert(p.children.length > 1 && p.children.length < 4);
				variables[p.children[1].matches[0]] = [p.children[0].matches[0]]; // assign the variable's type
				if (p.children.length == 3) { // this is an initialization
					parseExpression(p.children[2]); // get initialization expression
					if (bitwidth[stack[$-1][1]] != "addr" && bitwidth[p.children[0].matches[0]] != "addr" && to!int(bitwidth[stack[$-1][1]]) > to!int(bitwidth[p.children[0].matches[0]])) {
						writefln("Compiler error (line %d): conflicting types for assignment: %s = %s",count(p.input[0..p.begin],"\n")+1,p.children[0].matches[0],stack[$-1][1]);
						exit(1);
					}

					instructions ~= "$" ~ to!string(stack.length-1) ~ " write_" ~ bitwidth[p.children[0].matches[0]] ~ " " ~ p.children[1].matches[0];
					stack = stack.remove(stack.length-1); // pop stack
				}
				return;
			case name ~ ".StatementBlock":
				foreach (m; p.children) { // just parse each child
					parseExpression(m);
				}

				return;
			case name ~ ".StatementIf":
				parseExpression(p.children[0]);
				instructions ~= "0 test== $" ~ to!string(stack.length-1); // note: $ locations are used as a stack, with higher numbers being higher on the stack.
				stack = stack.remove(stack.length-1);
				int oldLabNum = labelNum; //  labelNum could change when expression is parsed
				instructions ~= "jmpi label" ~ to!string(labelNum++); // the jmpi skips code if expression false
				parseExpression(p.children[1]);
				instructions ~= "label" ~ to!string(oldLabNum) ~ ":";
				return;
			case name ~ ".StatementWhile":
				/* While loops are like this:
				 * lab1:
				 * (evaluate expression)
				 * if (expression is false) jmp lab2
				 * (evaluate loop body)
				 * jmp lab1
				 * lab2:
				 */
				int startLabNum = labelNum; // label of start of loop
				instructions ~= "label" ~ to!string(labelNum++) ~ ":";
				parseExpression(p.children[0]);
				int endLabNum = labelNum++; // label after loop
				instructions ~= "0 test== $" ~ to!string(stack.length-1);
				stack = stack.remove(stack.length-1); // pop stack
				instructions ~= "jmpi label" ~ to!string(endLabNum);
				parseExpression(p.children[1]);
				instructions ~= "jmp label" ~ to!string(startLabNum);
				instructions ~= "label" ~ to!string(endLabNum) ~ ":";
				return;
			case name ~ ".ExpressionAssignLeft":
				parseExpression(p.children[0]);
				if (p.matches[0] == "*") { // something like *p = 5; or *(x+5) = b;
					if (!stack[$-1][1].endsWith("*")) { // you can't dereference something that's not a pointer
						writefln("Compiler error (line %d): type %s is not a pointer.",count(p.input[0..p.begin],"\n")+1,stack[$-1][1]);
						exit(1);
					}
					
					if (stack[$-1][2] == "yes") {
						stack[$-1][2] = "no"; // if it's an address dereference it first
						instructions ~= "$" ~ to!string(stack.length-1) ~ " read_" ~ to!string(bitwidth[stack[$-1][1]]) ~ " $" ~ to!string(stack.length-1);
					}
					stack[$-1][1] = stack[$-1][1][0..$-1]; // dereference the type by removing *

				}

				return;
			case name ~ ".Expression":
				parseExpression(p.children[$-1]); // parse the right side of an assignment if we're doing an assignment
				if (p.children[0].name == name ~ ".ExpressionAssignLeft") { // we are doing assignment
					parseExpression(p.children[0]); // parse the left side
					assert(stack[$-1][1] in bitwidth);
					if (bitwidth[stack[$-1][1]] != "addr" && bitwidth[stack[$-2][1]] != "addr" && to!int(bitwidth[stack[$-1][1]]) < to!int(bitwidth[stack[$-2][1]])) {
						writefln("Compiler error (line %d): conflicting types for assignment: %s = %s",count(p.input[0..p.begin],"\n")+1,stack[$-1][1],stack[$-2][1]);
						exit(1);
					}
					if (p.children[1].matches[0] != "=") { // compound assignment
						instructions ~= "$" ~ to!string(stack.length) ~ " read_" ~ bitwidth[stack[$-1][1]] ~ " $" ~ to!string(stack.length-1);
						instructions ~= "$" ~ to!string(stack.length) ~ " " ~ p.children[1].matches[0] ~ " " ~ "$" ~ to!string(stack.length-2);
						instructions ~= "$" ~ to!string(stack.length-2) ~ " = $" ~ to!string(stack.length);
					}
					instructions ~= "$" ~ to!string(stack.length-2) ~ " write_" ~ bitwidth[stack[$-1][1]] ~ " $" ~ to!string(stack.length-1);
					stack = stack.remove(stack.length-1); // pop stack
				}
				return;
			case name ~ ".IntegerLiteral":
				assert(p.children.length = p.matches[0].length, "An IntegerLiteral has incorrect number of children.");
				instructions ~= "$" ~ to!string(stack.length) ~ " = " ~ p.matches[0]; // push stack
				if (to!int(p.matches[0]) >= 2^^16) { // this detects if it can fit in a short
					stack ~= ["","int","no"];	
				} else {
					stack ~= ["","short","no"];
				}
				return;
			case name ~ ".CharLiteral":
				instructions ~= "$" ~ to!string(stack.length) ~ " = " ~ to!string(to!int(p.matches[1][0])); // push stack
				stack ~= ["","char","no"];
				return;
			case name ~ ".StringLiteral":
				instructions ~= "$" ~ to!string(stack.length) ~ " = temp" ~ to!string(temps.length); // push temp value onto stack
				stack ~= ["","char*","no"];
				temps ~= [[]]; // temps is an array of arrays of memory cell values
				foreach(c; p.matches[1]) {
					temps[$-1] ~= c;
				}
				temps[$-1] ~= 0; // null terminate
				return;
			case name ~ ".AddrVariable":
				addrVariable = true;
				goto case; // fall through, AddrVariable is like variable but has addrVariable = true
			case name ~ ".Variable":
				if (p.matches[0] !in variables) {
					writefln("Compiler error (line %d): variable %s not defined.", count(p.input[0..p.begin],"\n")+1,p.matches[0]);
					exit(1);
				}

				instructions ~= "$" ~ to!string(stack.length) ~ (addrVariable ? " = " : " read_" ~ bitwidth[variables[p.matches[0]][0]] ~ " ") ~ p.matches[0];
				stack ~= [p.matches[0],variables[p.matches[0]][0],addrVariable ? "yes" : "no"];
				return;
			case name ~ ".Sizeof":
				if (p.children[0].matches[0] in bitwidth) { // we are taking sizeof a type
					instructions ~= "$" ~ to!string(stack.length) ~ " = " ~ bitwidth[p.children[0].matches[0]]; // push stack
				} else { // sizeof a variable
					if (p.children[0].matches[0] !in variables) {
						writefln("Compiler error (line %d): variable %s not defined.", count(p.input[0..p.begin],"\n")+1,p.matches[0]);
						exit(1);
					}
					instructions ~= "$" ~ to!string(stack.length) ~ " = " ~ bitwidth[variables[p.children[0].matches[0]][0]]; // push stack
				}
				stack ~= ["","int","no"]; // sizeofs are ints
				return;
			case name ~ ".ExpressionUnaryPost":
				parseExpression(p.children[0]);
				if (p.children.length > 1) { // we are incrementing or decrementing
					assert(p.children.length == 2);
					assert(p.children[1].matches[0] == "++" || p.children[1].matches[0] == "--");
					if (stack[$-1][2] == "no") {
						instructions ~= "push $" ~ to!string(stack.length-1);
					}
					instructions ~= "$" ~ to!string(stack.length-1) ~ " read_" ~ bitwidth[stack[$-1][1]] ~ " $" ~ to!string(stack.length-1);
					if (stack[$-1][2] == "yes") {
						instructions ~= "push $" ~ to!string(stack.length-1); // store the value because postfix increment/decrement doesn't change it
					}
					instructions ~= p.children[1].matches[0] ~ " $" ~ to!string(stack.length-1); // increment or decrement
					instructions ~= "$" ~ to!string(stack.length-1) ~ " write_" ~ bitwidth[stack[$-1][1]] ~ " " ~ stack[$-1][0]; // update variable
					instructions ~= "pop $" ~ to!string(stack.length-1); // restore value
					stack[$-1][2] = "no";
				}

				return;
			case name ~ ".ExpressionUnaryPre":
				parseExpression(p.children[$-1]);
				foreach(m; p.children[0..$-1]) {
					if (m.matches[0] == "+") continue; // unary plus does nothing
					if (m.matches[0] == "*") {
						if (!stack[$-1][1].endsWith("*")) { // can't deference a non-pointer
							writefln("Compiler error (line %d): type %s is not a pointer.",count(p.input[0..p.begin],"\n")+1,stack[$-1][1]);
							exit(1);
						}

						instructions ~= "$" ~ to!string(stack.length-1) ~ " read_" ~ bitwidth[stack[$-1][1][0..$-1]] ~ " $" ~ to!string(stack.length-1);
						stack[$-1][1] = stack[$-1][1][0..$-1]; // dereference the type by removing *
					} else if (m.matches[0] == "&") {
						if (stack[$-1][2] == "no") { // not an addrvariable so we don't know its address
							writefln("Compiler error (line %d): this is not a variable!",count(p.input[0..p.begin],"\n")+1);
							exit(1);
						}

						stack[$-1][1] = stack[$-1][1] ~ "*"; // reference the type by adding *, we don't need to do anything since the value is already an address
						stack[$-1][1] = "no"; // now it's not an address
					} else if (m.matches[0].endsWith(")")) { // a typecast
						stack[$-1][1] = m.matches[0][1..$-1]; // just change the type
					} else { // some run-of-the-mill unary operation
						instructions ~= m.matches[0] ~ " $" ~ to!string(stack.length-1); // perform operation
						if (m.matches[0] == "++" || m.matches[0] == "--") { // update variable if increment or decrement
							instructions ~= "$" ~ to!string(stack.length-1) ~ " write_" ~ bitwidth[stack[$-1][1]] ~ " " ~ stack[$-1][0];
						}

					}

				}

				return;
			case name ~ ".ExpressionSum":
			case name ~ ".ExpressionProd":
			case name ~ ".ExpressionShift":
			case name ~ ".ExpressionBitAnd":
			case name ~ ".ExpressionBitXor":
			case name ~ ".ExpressionBitOr": // these are all binary operations that don't involve test
				parseExpression(p.children[0]);
				foreach(m; p.children[1..$]) {
					assert(canFind(["+","-","*","/","%","&","|","^","<<",">>"], m.matches[0]), "Expression binary operation " ~ name ~ " tried to use operator " ~ m.matches[0] ~ ".");
					parseExpression(m);
					string higher = bitwidth[stack[$-1][1]] > bitwidth[stack[$-2][1]] ? stack[$-1][1] : stack[$-2][1];
					string lower = bitwidth[stack[$-1][1]] > bitwidth[stack[$-2][1]] ? stack[$-2][1] : stack[$-1][1];
					int which = bitwidth[stack[$-1][1]] > bitwidth[stack[$-2][1]] ? 1 : 2; // which stack index has a higher bitwidth
					switch (higher) { // we will increase the result to the higher bitwidth
						case "char":
						case "int":
						case "short":
							instructions ~= "$" ~ to!string(stack.length-2) ~ " " ~ m.matches[0] ~ "= $" ~ to!string(stack.length-1);
							stack = stack.remove(stack.length-1);
							stack[$-1][1] = higher;
							break;
						case "char*": // pointer types mean pointer arithmetic
						case "int*":
						case "short*":
							if ((lower == "int" || lower == "char" || lower == "short") && (m.matches[0] == "+" || m.matches[0] == "-")) {
								instructions ~= "$" ~ to!string(stack.length-(3-which)) ~ " *= " ~ bitwidth[lower];
								instructions ~= "$" ~ to!string(stack.length-(which)) ~ " " ~ m.matches[0] ~ "= $" ~ to!string(stack.length-(3-which));
								if (which == 1) {
									instructions ~= "$" ~ to!string(stack.length-2) ~ " = $" ~ to!string(stack.length-1);
								}
								stack = stack.remove(stack.length-1);
								stack[$-1][1] = higher;
								break;
							}
							goto default;
						default:
							writefln("Compiler error (line %d): invalid types: %s %s %s",count(p.input[0..p.begin],"\n")+1,stack[$-2][1],m.matches[0],stack[$-1][1]);
							exit(1);
					}

				}

				return;
			case name ~ ".ExpressionEq":
			case name ~ ".ExpressionCmp":
			case name ~ ".ExpressionLogAnd":
			case name ~ ".ExpressionLogOr":	// binary operations involving test
				parseExpression(p.children[0]);
				foreach(m; p.children[1..$]) {
					assert(canFind(["==","!=","<",">","<=",">=","&&","||"], m.matches[0]), "Expression logical operation " ~ name ~ " tried to use operator " ~ m.matches[0] ~ ".");
					parseExpression(m);
					instructions ~= "$" ~ to!string(stack.length-2) ~ " test" ~ m.matches[0] ~ " $" ~ to!string(stack.length-1);
					instructions ~= "test $" ~ to!string(stack.length-2); // get test result 1 or 0
					stack = stack.remove(stack.length-1); // pop stack
				}

				return;
			case name ~ ".ExpressionTernary":
				parseExpression(p.children[0]);
				if (p.children.length > 1) {
					assert(p.children.length == 3, "ExpressionTernary must have three children.");
					instructions ~= "$" ~ to!string(stack.length-1) ~ " test== 0";
					stack = stack.remove(stack.length-1);
					int oldLabNum = labelNum; // label to jump to if false to skip true code
					instructions ~= "jmpi label" ~ to!string(labelNum++);
					parseExpression(p.children[1]); // true code
					int oldLabNum2 = labelNum; // label to jump to if true to skip false code
					instructions ~= "jmp label" ~ to!string(labelNum++);
					instructions ~= "label" ~ to!string(oldLabNum) ~ ":";
					parseExpression(p.children[2]); // false code
					instructions ~= "label" ~ to!string(oldLabNum2) ~ ":";
				}

				return;
			default:
				assert(p.children.length == 1, "Too many children for " ~ p.name);
				parseExpression(p.children[0]);
				return;
		}

	}

	parseExpression(tree);
	instructions ~= "end"; // halt at end of program
	foreach(string vname, string[] attributes; variables) {
		instructions ~= vname ~ ":";
		if (bitwidth[attributes[0]] == "addr") {
			instructions ~= "addr 0";
		} else {
			foreach(i;0..to!int(bitwidth[attributes[0]])) instructions ~= "data 0"; // allocate enough space for the variable
		}

	}

	foreach(id, int[] content; temps) {
		instructions ~= "temp" ~ to!string(id) ~ ":";
		foreach(int v; content) { // just allocate the content we have stored
			instructions ~= "data " ~ to!string(v);
		}

	}

	return instructions; // and that's all there is to it
}

