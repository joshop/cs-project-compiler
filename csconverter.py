code = ["$0 = temp0", "$0 write_addr mystring", "label0:", "$0 read_addr mystring", "$0 read_1 $0", "0 test== $0", "jmpi label1", "$0 read_addr mystring", "$0 read_1 $0", "$1 = tmp", "$0 write_1 $1", "$0 read_1 tmp", "$1 = 97", "$0 test>= $1", "test $0", "$1 read_1 tmp", "$2 = 122", "$1 test<= $2", "test $1", "$0 test&& $1", "test $0", "0 test== $0", "jmpi label3", "$0 = 32", "$1 read_addr mystring", "$2 read_1 $1", "$2 -= $0", "$0 = $2", "$0 write_1 $1", "label2:", "$0 read_1 tmp", "$1 = 65", "$0 test>= $1", "test $0", "$1 read_1 tmp", "$2 = 90", "$1 test<= $2", "test $1", "$0 test&& $1", "test $0", "0 test== $0", "jmpi label5", "$0 = 32", "$1 read_addr mystring", "$2 read_1 $1", "$2 += $0", "$0 = $2", "$0 write_1 $1", "label4:", "$0 = mystring", "push $0", "$0 read_addr $0", "++ $0", "$0 write_addr mystring", "pop $0", "jmp label0", "label1:", "end", "tmp:", "data 0", "mystring:", "addr 0", "temp0:", "data 104", "data 111", "data 119", "data 32", "data 78", "data 79", "data 87", "data 32", "data 98", "data 82", "data 111", "data 119", "data 110", "data 32", "data 67", "data 79", "data 119", "data 0"]
cond = "e"
tl = 0
for line in code:
	p = line.replace("$0", "ax").replace("$1","bx").replace("$2","cx").replace("$3","dx").split()
	if p[0] == "end":
		print("ret")
	elif p[0].endswith(":"):
		print(p[0])
	elif p[0] == "data":
		print("db "+p[1])
	elif p[0] == "addr":
		print("db "+str(int(p[1])%256))
		print("db "+str(int(p[1])//256))
	elif p[0] == "jmpi":
		print("j"+cond+" "+p[1])
	elif p[0] == "jmp" or p[0] == "push" or p[0] == "pop":
		print(' '.join(p))
	elif p[0] == "++":
		print("inc "+p[1])
	elif p[0] == "--":
		print("dec "+p[1])
	elif p[0] == "-":
		print("neg "+p[1])
	elif p[0] == "~":
		print("not "+p[1])
	elif p[0] == "!":
		print("cmp "+p[1]+", 0")
		print("je tl"+str(tl))
		tl += 1
		print("mov "+p[1]+", 1")
		print("jmp tl"+str(tl))
		tl += 1
		print("tl"+str(tl-2)+":")
		print("mov "+p[1]+", 0")
		print("tl"+str(tl-1)+":")
	elif p[0] == "test":
		print("j"+cond+" tl"+str(tl))
		tl += 1
		print("mov "+p[1]+", 0")
		print("jmp tl"+str(tl))
		tl += 1
		print("tl"+str(tl-2)+":")
		print("mov "+p[1]+", 1")
		print("tl"+str(tl-1)+":")
	elif p[1] == "=":
		print("mov "+p[0]+", "+p[2])
	elif p[1] == "+=":
		print("add "+p[0]+", "+p[2])
	elif p[1] == "-=":
		print("sub "+p[0]+", "+p[2])
	elif p[1] == "&=":
		print("and "+p[0]+", "+p[2])
	elif p[1] == "|=":
		print("or "+p[0]+", "+p[2])
	elif p[1] == "^=":
		print("xor "+p[0]+", "+p[2])
	elif p[1] == ">>=":
		print("shr "+p[0]+", "+p[2])
	elif p[1] == "<<=":
		print("shl "+p[0]+", "+p[2])
	elif p[1] == "write_1":
		print("mov di, "+p[2])
		print("mov [di], "+p[0].replace("x","l"))
	elif p[1] == "write_2" or p[1] == "write_addr":
		print("mov di, "+p[2])
		print("mov [di], "+p[0])
	elif p[1] == "read_1":
		print("mov si, "+p[2])
		print("mov "+p[0]+", [si]")
		print("mov "+p[0].replace("x","h")+", 0")
	elif p[1] == "read_2" or p[1] == "read_addr":
		print("mov si, "+p[2])
		print("mov "+p[0]+", [si]")
	elif p[1] == "test&&":
		print("cmp "+p[0]+", 0")
		print("je tl"+str(tl))
		print("cmp "+p[2]+", 0")
		print("je tl"+str(tl))
		tl += 1
		print("cmp ax, ax")
		print("jmp tl"+str(tl))
		tl += 1
		print("tl"+str(tl-2)+":")
		print("mov si, ax")
		print("not si")
		print("cmp ax, si")
		print("tl"+str(tl-1)+":")
	elif p[1] == "test||":
		print("cmp "+p[0]+", 0")
		print("jne tl"+str(tl))
		print("cmp "+p[2]+", 0")
		print("jne tl"+str(tl))
		tl += 1
		print("mov si, ax")
		print("not si")
		print("cmp ax, si")
		print("jmp tl "+str(tl))
		tl += 1
		print("tl"+str(tl-2)+":")
		print("cmp ax, ax")
		print("tl"+str(tl-1)+":")
	elif p[1].startswith("test"):
		if not "x" in p[0]:
			print("mov si, "+p[0])
			print("cmp "+p[0]+", "+p[2])
		else:
			print("cmp "+p[0]+", "+p[2])
		if p[1] == "test==":
			cond = "e"
		elif p[1] == "test!=":
			cond = "ne"
		elif p[1] == "test>":
			cond = "g"
		elif p[1] == "test<":
			cond = "l"
		elif p[1] == "test>=":
			cond = "ge"
		elif p[1] == "test<=":
			cond = "le"
		else:
			raise ValueError(p[1])
	else:
		raise ValueError(p)
