import pegged.grammar;
import std.range : chunks;
import std.stdio: writeln, writefln;
import std.conv: to;
import std.algorithm.searching: canFind, endsWith, count;
import std.algorithm.mutation: remove;
import core.stdc.stdlib: exit;
enum string name = "CMinusMinus";
mixin(grammar(name ~ `:
Start < Statement
IntegerLiteral < ~([0-9]+)
Variable < ~(identifier)
AddrVariable < ~(identifier)
Dereference < '&'
Type < ~(Type '*' / 'int')
IncDec < '++' / '--'
Statement < ';' / StatementDeclare ';' / Expression ';' / StatementBlock
StatementBlock < '{' Statement* '}'
StatementDeclare < Type Variable ('=' Expression)?
Sizeof < 'sizeof' '('? (Type / Variable) ')'?
ExpressionAtom < Sizeof / '(' Expression ')' / IntegerLiteral / Variable
ExpressionUnaryPost < ExpressionAssignLeft IncDec / ExpressionAtom
ExpressionUnaryPreRep < '-' / '+' / '~' / '!' / '*' / ~('(' Type ')')
ExpressionUnaryPre < IncDec ExpressionAssignLeft / ExpressionUnaryPreRep* (ExpressionUnaryPost / Dereference* ExpressionAssignLeft)
ExpressionProdRep < ('*' / '/' / '%') ExpressionUnaryPre
ExpressionProd < ExpressionUnaryPre ExpressionProdRep*
ExpressionSumRep < ('+' / '-') ExpressionProd
ExpressionSum < ExpressionProd ExpressionSumRep*
ExpressionShiftRep < ('<<' / '>>') ExpressionSum
ExpressionShift < ExpressionSum ExpressionShiftRep*
ExpressionCmpRep < ('<' / '>' / '<=' / '>=') ExpressionShift
ExpressionCmp < ExpressionShift ExpressionCmpRep*
ExpressionEqRep < ('==' / '!=') ExpressionCmp
ExpressionEq < ExpressionCmp ExpressionEqRep*
ExpressionBitAndRep < '&' ExpressionEq
ExpressionBitAnd < ExpressionEq ExpressionBitAndRep*
ExpressionBitXorRep < '^' ExpressionBitAnd
ExpressionBitXor < ExpressionBitAnd ExpressionBitXorRep*
ExpressionBitOrRep < '|' ExpressionBitXor
ExpressionBitOr < ExpressionBitXor ExpressionBitOrRep*
ExpressionLogAndRep < '&&' ExpressionBitOr
ExpressionLogAnd < ExpressionBitOr ExpressionLogAndRep*
ExpressionLogOrRep < '||' ExpressionLogAnd
ExpressionLogOr < ExpressionLogAnd ExpressionLogOrRep*
ExpressionTernary < ExpressionLogOr ('?' ExpressionLogOr ':' ExpressionLogOr)?
Expression < (ExpressionAssignLeft ('=' / '+=' / '-=' / '*=' / '/=' / '%=' / '<<=' / '>>=' / '&=' / '|=' / '^='))? ExpressionTernary
ExpressionAssignLeft < AddrVariable / '*' ExpressionTernary
`));
/* This compiler outputs Machine Agnostic Assembly. This is a basic assembly-like intermediate language where all lines should ideally compile to one or two machine instructions.
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
enum string[string] bitwidth = ["int": "4", "int*": "addr"];
void main() {
	//writeln(compile("*b"));
	writeln(compile("{int *b; *(b+1) = 8;}"));
}
string[] compile(string code) {
	auto tree = CMinusMinus(code);
	writeln(tree);
	string[][] stack;
	string[] instructions;
	int labelNum = 0;
	void parseExpression(ParseTree p) {
		bool addrVariable = false;
		switch (p.name) {
			case name ~ ".Statement":
				if (p.children.length > 0) {
					assert(p.children.length == 1);
					parseExpression(p.children[0]);
				}
				return;	
			case name ~ ".StatementDeclare":
				assert(p.children.length > 1 && p.children.length < 4);
				variables[p.children[1].matches[0]] = [p.children[0].matches[0]];
				if (p.children.length == 3) {
					parseExpression(p.children[2]);
					if (stack[$-1][1] != p.children[0].matches[0]) {
						writefln("Compiler error (line %d): conflicting types for assignment: %s = %s",count(p.input[0..p.begin],"\n")+1,p.children[0].matches[0],stack[$-1][1]);
						exit(1);
					}
					instructions ~= "$" ~ to!string(stack.length-1) ~ " write_" ~ bitwidth[p.children[0].matches[0]] ~ " " ~ p.children[1].matches[0];
					stack = stack.remove(stack.length-1);
				}
				return;
			case name ~ ".StatementBlock":
				foreach (m; p.children) {
					parseExpression(m);
				}
				return;
			case name ~ ".ExpressionAssignLeft":
				parseExpression(p.children[0]);
				if (p.matches[0] == "*") {
					if (!stack[$-1][1].endsWith("*")) {
						writefln("Compiler error (line %d): type %s is not a pointer.",count(p.input[0..p.begin],"\n")+1,stack[$-1][1]);
						exit(1);
					}
					//instructions ~= "$" ~ to!string(stack.length-1) ~ " read_" ~ bitwidth[stack[$-1][1][0..$-1]] ~ " $" ~ to!string(stack.length-1);
					stack[$-1][1] = stack[$-1][1][0..$-1];
				}
				return;
			case name ~ ".Expression":
				parseExpression(p.children[$-1]);
				if (p.children[0].name == name ~ ".ExpressionAssignLeft") {
					parseExpression(p.children[0]);
					assert(stack[$-1][1] in bitwidth);
					if (stack[$-1][1] != stack[$-2][1]) {
						writefln("Compiler error (line %d): conflicting types for assignment: %s = %s",count(p.input[0..p.begin],"\n")+1,stack[$-1][1],stack[$-2][1]);
						exit(1);
					}
					instructions ~= "$" ~ to!string(stack.length-2) ~ " write_" ~ bitwidth[stack[$-1][1]] ~ " $" ~ to!string(stack.length-1);
					stack = stack.remove(stack.length-2,stack.length-1);
				}
				return;
			case name ~ ".IntegerLiteral":
				assert(p.children.length = p.matches[0].length, "An IntegerLiteral has incorrect number of children.");
				instructions ~= "$" ~ to!string(stack.length) ~ " = " ~ p.matches[0];
				stack ~= ["","int","no"];	
				return;
			case name ~ ".AddrVariable":
				addrVariable = true;
				goto case;
			case name ~ ".Variable":
				if (p.matches[0] !in variables) {
					writefln("Compiler error (line %d): variable %s not defined.", count(p.input[0..p.begin],"\n")+1,p.matches[0]);
					exit(1);
				}
				instructions ~= "$" ~ to!string(stack.length) ~ (addrVariable ? " = " : " read_" ~ bitwidth[variables[p.matches[0]][0]] ~ " ") ~ p.matches[0];
				stack ~= [p.matches[0],variables[p.matches[0]][0],addrVariable ? "yes" : "no"];
				return;
			case name ~ ".Sizeof":
				if (p.children[0].matches[0] in bitwidth) {
					instructions ~= "$" ~ to!string(stack.length) ~ " = " ~ bitwidth[p.children[0].matches[0]];
				} else {
					if (p.children[0].matches[0] !in variables) {
						writefln("Compiler error (line %d): variable %s not defined.", count(p.input[0..p.begin],"\n")+1,p.matches[0]);
						exit(1);
					}
					instructions ~= "$" ~ to!string(stack.length) ~ " = " ~ bitwidth[variables[p.children[0].matches[0]][0]];
				}
				stack ~= ["","int","no"];
				return;
			case name ~ ".ExpressionUnaryPost":
				parseExpression(p.children[0]);
				if (p.children.length > 1) {
					assert(p.children.length == 2);
					assert(p.children[1].matches[0] == "++" || p.children[1].matches[0] == "--");
					instructions ~= "push $" ~ to!string(stack.length-1);
					instructions ~= p.children[1].matches[0] ~ " $" ~ to!string(stack.length-1);
					instructions ~= "$" ~ to!string(stack.length-1) ~ " write_" ~ bitwidth[stack[$-1][1]] ~ " " ~ stack[$-1][0];
					instructions ~= "pop $" ~ to!string(stack.length-1);
				}
				return;
			case name ~ ".ExpressionUnaryPre":
				parseExpression(p.children[$-1]);
				foreach(m; p.children[0..$-1]) {
					if (m.matches[0] == "+") continue;
					if (m.matches[0] == "*") {
						if (!stack[$-1][1].endsWith("*")) {
							writefln("Compiler error (line %d): type %s is not a pointer.",count(p.input[0..p.begin],"\n")+1,stack[$-1][1]);
							exit(1);
						}
						instructions ~= "$" ~ to!string(stack.length-1) ~ " read_" ~ bitwidth[stack[$-1][1][0..$-1]] ~ " $" ~ to!string(stack.length-1);
						stack[$-1][1] = stack[$-1][1][0..$-1];
					} else if (m.matches[0] == "&") {
						if (stack[$-1][2] == "no") {
							writefln("Compiler error (line %d): this is not a variable!",count(p.input[0..p.begin],"\n")+1);
							exit(1);
						}
						stack[$-1][1] = stack[$-1][1] ~ "*";
					} else if (m.matches[0].endsWith(")")) {
						stack[$-1][1] = m.matches[0][1..$-1];
					} else {
						instructions ~= m.matches[0] ~ " $" ~ to!string(stack.length-1);
						if (m.matches[0] == "++" || m.matches[0] == "--") {
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
			case name ~ ".ExpressionBitOr":
				parseExpression(p.children[0]);
				foreach(m; p.children[1..$]) {
					assert(canFind(["+","-","*","/","%","&","|","^","<<",">>"], m.matches[0]), "Expression binary operation " ~ name ~ " tried to use operator " ~ m.matches[0] ~ ".");
					parseExpression(m);
					string higher = bitwidth[stack[$-1][1]] > bitwidth[stack[$-2][1]] ? stack[$-1][1] : stack[$-2][1];
					string lower = bitwidth[stack[$-1][1]] > bitwidth[stack[$-2][1]] ? stack[$-2][1] : stack[$-1][1];
					int which = bitwidth[stack[$-1][1]] > bitwidth[stack[$-2][1]] ? 1 : 2;
					switch (higher) {
						case "int":
							instructions ~= "$" ~ to!string(stack.length-2) ~ " " ~ m.matches[0] ~ "= $" ~ to!string(stack.length-1);
							stack = stack.remove(stack.length-1);
							break;
						case "int*":
							if (lower == "int" && (m.matches[0] == "+" || m.matches[0] == "-")) {
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
			case name ~ ".ExpressionLogOr":	
				parseExpression(p.children[0]);
				foreach(m; p.children[1..$]) {
					assert(canFind(["==","!=","<",">","<=",">=","&&","||"], m.matches[0]), "Expression logical operation " ~ name ~ " tried to use operator " ~ m.matches[0] ~ ".");
					parseExpression(m);
					instructions ~= "$" ~ to!string(stack.length-2) ~ " test" ~ m.matches[0] ~ " $" ~ to!string(stack.length-1);
					instructions ~= "test $" ~ to!string(stack.length-2);
					stack = stack.remove(stack.length-1);
				}
				return;
			case name ~ ".ExpressionTernary":
				parseExpression(p.children[0]);
				if (p.children.length > 1) {
					assert(p.children.length == 3, "ExpressionTernary must have three children.");
					instructions ~= "$" ~ to!string(stack.length-1) ~ " test== 0";
					instructions ~= "jmpi label" ~ to!string(labelNum++);
					parseExpression(p.children[1]);
					instructions ~= "jmp label" ~ to!string(labelNum++);
					instructions ~= "label" ~ to!string(labelNum-2) ~ ":";
					parseExpression(p.children[2]);
					instructions ~= "label" ~ to!string(labelNum-1) ~ ":";
				}
				return;
			default:
				if (p.name == name ~ ".ExpressionUnaryPreRep") {
					writeln(p.children);
				}	
				assert(p.children.length == 1, "Too many children for " ~ p.name);
				parseExpression(p.children[0]);
				return;
		}
	}
	parseExpression(tree);
	instructions ~= "end";
	foreach(string vname, string[] attributes; variables) {
		instructions ~= vname ~ ":";
		if (bitwidth[attributes[0]] == "addr") {
			instructions ~= "addr 0";
		} else {
			foreach(i;0..to!int(bitwidth[attributes[0]])) instructions ~= "data 0";
		}
	}
	return instructions;
}
