module tis::assembler::grammar;

import std::io;

enum ENUM_PreprocessorInstructionLabel {
	PREPROCESSOR,
	INSTRUCTION,
	LABEL
}

enum ENUM_PreprocessorPost {
	IDENTIFIER,
	NUMBER,
	LABEL
}

constdef ENUM_Instruction : char {
	ARITHMETIC = 0b00,
	LOGISTIC = 0b01,
	CONTROL_SWITCH = 0b10,
	OTHER = 0b11
}

constdef ENUM_ArithmeticOpcode : char {
	ADD = 0b000,
	SUB = 0b001,
	MUL = 0b010,
	DIV = 0b011,
	MOD = 0b100,
	SLL = 0b101,
	SRL = 0b110,
	NOT = 0b111
}

enum ENUM_Argument {
	REGISTER,
	LITERAL,
	LABEL
}

constdef ENUM_Register : char {
	NIL = 0b000,
	A = 0b001,
	B = 0b010,
	C = 0b011,
	D = 0b100,
	STACK = 0b101
}

constdef ENUM_ControlSwitchOpcode : char {
	JMP = 0b000,
	JE = 0b001,
	JNE = 0b010,
	JG = 0b011,
	JL = 0b100,
	JGE = 0b101,
	JLE = 0b110,
	CALL = 0b111
}

constdef ENUM_OtherOpcode : char {
	AND = 0b000,
	OR = 0b001,
	XOR = 0b010,
	LOAD8 = 0b011,
	LOAD16 = 0b100,
	STORE8 = 0b101,
	STORE16 = 0b110,
	SYSCALL = 0b111
}

enum TokenValid {
	FALSE,
	TRUE,
	ERROR
}

struct Other (Printable) {
	ENUM_OtherOpcode opcode;
	Argument argument; // Syscall can't have a label as argument
}

struct ControlSwitch (Printable) {
	ENUM_ControlSwitchOpcode opcode;

	// JMP and CALL only have 'argument'
	Argument argument;
	String label; 
}

struct Logistic (Printable) {
	ENUM_Register reg1_type;

	Argument reg2_argument;
}

struct Arithmetic (Printable) {
	ENUM_ArithmeticOpcode opcode;
	Argument argument;
}

struct Argument (Printable) {
	ENUM_Argument type;

	union {
		ENUM_Register register;
		int literal;
		String label;
	}
}

struct Instruction (Printable) {
	ENUM_Instruction type;

	union {
		Arithmetic arithmetic;
		Logistic logistic;
		ControlSwitch control_switch;
		Other other;
	}
}

struct PreprocessorPost (Printable) {
	ENUM_PreprocessorPost type;

	union {
		String identifier;
		int number;
		String label;
	}
}

struct Preprocessor (Printable) {
	String preprocessor_id;
	PreprocessorPost preprocessor_post;
}

struct PreprocessorInstructionLabel (Printable) {
	ENUM_PreprocessorInstructionLabel type;
	union {
		Preprocessor preprocessor_id;
		Instruction instruction_id;
		String label_id;
	}
}

struct Token {
	char* str;
	uint len;
	uint line;
}

fn usz? Other.to_format(&self, Formatter* format) @dynamic {
	usz n = 0;
	n += format.printf("%s ", self.opcode)!;
	n += format.printf("[%s]", self.argument)!;
	return n;
}

fn usz? ControlSwitch.to_format(&self, Formatter* format) @dynamic {
	usz n = 0;
	n += format.printf("%s ", self.opcode)!;
	n += format.printf("[%s] ", self.argument)!;
	n += format.printf("LABEL: [%s]", self.label)!;
	return n;
}

fn usz? Logistic.to_format(&self, Formatter* format) @dynamic {
	usz n = 0;
	n += format.print("MOV ")!;
	n += format.printf("[%s] ", self.reg1_type)!;
	n += format.printf("[%s] ", self.reg2_argument)!;
	return n;
}

fn usz? Arithmetic.to_format(&self, Formatter* format) @dynamic {
	usz n = 0;
	n += format.printf("%s ", self.opcode)!;
	n += format.printf("[%s]", self.argument)!;
	return n;
}

fn usz? Argument.to_format(&self, Formatter* format) @dynamic {
	usz n = 0;
	
	n += format.printf("Argument [%s] ", self.type)!;
	switch (self.type) {
		case REGISTER:
			n += format.printf("[%s] ", self.register)!;
		case LITERAL:
			n += format.printf("[%s] ", self.literal)!;
		case LABEL:
			n += format.printf("Label: [%s]", self.label)!;
	}
	return n;
}

fn usz? Instruction.to_format(&self, Formatter* format) @dynamic {
	usz n = 0;
	n += format.printf("Instruction [%s] ", self.type)!;

	switch (self.type) {
		case ARITHMETIC:
			n += format.printf("Arithmetic [%s] ", self.arithmetic)!;
		case LOGISTIC:
			n += format.printf("Logistic [%s] ", self.logistic)!;
		case CONTROL_SWITCH:
			n += format.printf("Control Switch [%s] ", self.control_switch)!;
		case OTHER:
			n += format.printf(" Other [%s]", self.other)!;
	}
	return n;
}

fn usz? PreprocessorPost.to_format(&self, Formatter* format) @dynamic {
	usz n = 0;
	n += format.printf("PreprocessorPost [%s] ", self.type)!;

	switch (self.type) {
		case IDENTIFIER:
			n += format.printf("IDENTIFIER: [%s] ", self.identifier)!;
		case NUMBER:
			n += format.printf("NUMBER: [%d] ", self.number)!;
		case LABEL:
			n += format.printf("LABEL: [%s]", self.label)!;
	}

	return n;
}

fn usz? Preprocessor.to_format(&self, Formatter* format) @dynamic {
	usz n = 0;
	n += format.printf("Preprocessor [%s] ", self.preprocessor_id)!;
	n += format.printf("[%s]", self.preprocessor_post)!;

	return n;
}

fn usz? PreprocessorInstructionLabel.to_format(&self, Formatter* format) @dynamic {
	usz n = 0;
	
	n += format.printf("Statement [%s] ", self.type)!;

	switch (self.type) {
		case PREPROCESSOR:
			n += format.printf("[%s] ", self.preprocessor_id)!;
		case INSTRUCTION:
			n += format.printf("[%s] ", self.instruction_id)!;
		case LABEL:
			n += format.printf("LABEL: [%s]", self.label_id)!;
	}

	return n;
}