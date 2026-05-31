module tis;

module tis::assembler;

import std;
import std::io;
import std::io::file;
import tis::assembler::grammar;

struct Info {
	List{Label} public_labels;
	List{Label} local_labels;
}

struct Label {
	String name;
	ushort offset;
	bool is_public;
	uint hash;
}

struct PreprocessedInstruction {
	Instruction instruction;
	ushort address;
	short requested_label1; // optional, used if the instruction has one or more labels
	short requested_label2; // optional, used if the instruction has one or more labels
	bool has_label1;
	bool has_label2;
}

struct SymbolList {
	uint total_symbol_size;
	ushort count;
	Symbol[1] symbols; // Variadic array
}

struct Symbol @packed {
	uint hash;
	ushort offset;
}

struct SymbolReference @packed {
	uint requested_hash;
	ushort designated_address; 
}

struct ObjectFile {
	uint file_size;
	
	SymbolList symbol_list;


}

const String ALPHANUMERIC_IDENTIFIER = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890_.";

macro bool is_space(char c) {
	return c == ' ' || c == '\t';
}

macro int next_alphanum_id(String str, uint start_pos) {
	int next_nonalphanum = -1;

	for (int i = start_pos; i < str.len; i++) {
		if (!ALPHANUMERIC_IDENTIFIER.contains(str[i])) {
			next_nonalphanum = i;
			return next_nonalphanum;
		}
	}

	return next_nonalphanum;
}

macro bool is_alphanum(Token str) {
	for (int i = 0; i < str.len; i++) {
		if (!str_contains_char(ALPHANUMERIC_IDENTIFIER, str.str[i])) {
			return false;
		}
	}

	return true;
}

macro bool str_contains_char(String str, char c) {
	for (int i = 0; i < str.len; i++) {
		if (str[i] == c) {
			return true;
		}
	}

	return false;
}

macro void skip_delim(String* str) {
	while (is_space(*(str.ptr++)));
}

macro bool is_integer(String str, int* i) {
	int? num = str.to_int();
	if (try num) {
		*i = num;
		return true;
	}
	else {
		return false;
	}
}

macro String Token.toString(&self) {
	return (String)self.str[:self.len];
}

macro void upper(String* str) {
	for (int i = 0; i < str.len; i++) {
		if ((*str)[i] >= 'a' && (*str)[i] <= 'z') {
			(*str)[i] -= 32;
		}
	}
}

fn void replace(String* s, char find, char replace) {
	for (int i = 0; i < s.len; i++) {
		if ((*s)[i] == find) {
			(*s)[i] = replace;
		}
	}
}

fn void lex(List{Token}* tokens, String code, uint line) {
	String[] tok = code.split(mem, " ");
	defer free(tok);

	for (int i = 0; i < tok.len; i++) {
		if (tok[i].len == 0) {
			continue;
		}

		uint last_pos = 0;
		int j = 0;

		if (tok[i][0] == '.' || tok[i][0] == ':') {
			tokens.push({.str = &tok[i][0], .len = 1, .line = line});
			last_pos = 1;
			j = 1;
		}
		
		for (j = 0; j < tok[i].len; j++) {
			// Might need to modify this in the future for strings
			if (tok[i][j] == '#') {
				return;
			}
			
			if (tok[i][j] == ' ') {
				last_pos = j + 1;
				continue;
			}

			if (!str_contains_char(ALPHANUMERIC_IDENTIFIER, tok[i][j])) {
				if ((j > last_pos)) {
					//io::printfn("TOK: %s, %d, %d", tok[i][last_pos .. j], last_pos, j - last_pos);
					tokens.push({.str = &tok[i][last_pos], .len = j - last_pos, .line = line});
					last_pos = j + 1;
				}
			}
		}

		
		if (last_pos < tok[i].len) {
			//io::printfn("FINAL TOK: %s, %d, %d", tok[i][last_pos .. tok[i].len - 1], last_pos, tok[i].len - last_pos);
			tokens.push({.str = &tok[i][last_pos], .len = tok[i].len - last_pos, .line = line});
		}
	}
}

fn bool tokenLabel(List{Token} tokens, PreprocessorInstructionLabel* pil, uint* index) {
	pil.type = LABEL;

	if (is_alphanum(tokens[*index])) {
		pil.label_id = tokens[*index].toString();
		(*index)++;
		return true;
	}
	else {
		io::printfn("ERROR: Expected an identifier after the ':' at token [%d] on line %d", *index, tokens[*index].line);
		return false;
	}
}

fn bool tokenPreprocessorPost(List{Token} tokens, Preprocessor* p, uint* index) {
	PreprocessorPost post;
	int val;

	if (tokens[*index].str[0] == ':') {
		post.type = LABEL;
		(*index)++;
		
		if (is_alphanum(tokens[*index])) {
			post.label = tokens[*index].toString();
			p.preprocessor_post = post;

			return true;
		}
		else {
			io::printfn("ERROR: Expected an identifier after the ':' at token [%d] on line %d.", *index, tokens[*index].line);
			return false;
		}
	}
	else if (is_integer(tokens[*index].toString(), &val)) {
		post.type = NUMBER;
		post.number = val;
		p.preprocessor_post = post;

		(*index)++;
		return true;
	}
	else if (is_alphanum(tokens[*index])) {
		post.type = IDENTIFIER;
		post.identifier = tokens[*index].toString();
		p.preprocessor_post = post;
		(*index)++;
		return true;
	}
	else {
		io::printfn("ERROR: Expected an identifier, integer literal, or label after '.' at token [%d] on line %d.", *index, tokens[*index].line);
		return false;
	}
}

fn bool tokenPreprocessor(List{Token} tokens, PreprocessorInstructionLabel* pil, uint* index) {
	pil.type = PREPROCESSOR;
	Preprocessor p;
	if (is_alphanum(tokens[*index])) {
		p.preprocessor_id = tokens[*index].toString();
		
		(*index)++;
		bool success = tokenPreprocessorPost(tokens, &p, index);
		pil.preprocessor_id = p;

		return success;
	}
	else {
		io::printfn("ERROR: Expected an identifier after the '.' on token [%d] on line %d.", *index, tokens[*index].line);
		return false;
	}
}

fn bool tokenArgument(List{Token} tokens, Argument* argument, uint* index) {
	int val;

	if (tokens[*index].str[0] == ':') {
		argument.type = LABEL;
		(*index)++;

		if (is_alphanum(tokens[*index])) {
			argument.label = tokens[*index].toString();
			(*index)++;
			return true;
		}
		else {
			io::printfn("ERROR: Expected an identifier after the ':' on token [%d] on line %d.", *index, tokens[*index].line);
			return false;
		}
	}
	else if (is_integer(tokens[*index].toString(), &val)) {
		argument.type = LITERAL;
		argument.literal = val;
		(*index)++;
		return true;
	}
	else if (is_alphanum(tokens[*index])) {
		argument.type = REGISTER;
		String register = tokens[*index].toString();
		upper(&register);

		switch (register) {
			case "NIL":
				argument.register = NIL;
			case "A":
				argument.register = A;
			case "B":
				argument.register = B;
			case "C":
				argument.register = C;
			case "D":
				argument.register = D;
			case "STACK":
				argument.register = STACK;
			default:
				io::printfn("ERROR: Unexpected identifier '%s' on token [%d] on line %d", tokens[*index].toString(), *index, tokens[*index].line);
		}

		(*index)++;
		return true;
	}
	else {
		io::printfn("ERROR: Expected a register, label, or literal on token [%d] on line %d.", *index, tokens[*index].line);
		return false;
	}
}

fn TokenValid tokenArithmetic(List{Token} tokens, Instruction* instruction, uint* index) {
	instruction.type = ARITHMETIC;

	String tok = tokens[*index].toString();
	upper(&tok);

	Arithmetic arithmetic;

	switch (tok) {
		case "ADD":
			arithmetic.opcode = ADD;
		case "SUB":
			arithmetic.opcode = SUB;
		case "MUL":
			arithmetic.opcode = MUL;
		case "DIV":
			arithmetic.opcode = DIV;
		case "MOD":
			arithmetic.opcode = MOD;
		case "SLL":
			arithmetic.opcode = SLL;
		case "SRL":
			arithmetic.opcode = SRL;
		case "NOT":
			arithmetic.opcode = NOT;
		default:
			return FALSE;
	}

	Argument argument;

	(*index)++;

	if (tokenArgument(tokens, &argument, index)) {
		arithmetic.argument = argument;
		instruction.arithmetic = arithmetic;
		return TRUE;
	}
	else {
		io::printfn("ERROR: Expected a register, literal, or label on token [%d] on line %d.", *index, tokens[*index].line);
		return ERROR;
	}
}

fn TokenValid tokenLogistic(List{Token} tokens, Instruction* instruction, uint* index) {
	instruction.type = LOGISTIC;

	String tok = tokens[*index].toString();
	upper(&tok);

	if (tok == "MOV") {
		(*index)++;

		Logistic logistic;
		Argument argument;

		String register = tokens[*index].toString();
		upper(&register);

		switch (register) {
			case "NIL":
				logistic.reg1_type = NIL;
			case "A":
				logistic.reg1_type = A;
			case "B":
				logistic.reg1_type = B;
			case "C":
				logistic.reg1_type = C;
			case "D":
				logistic.reg1_type = D;
			case "STACK":
				logistic.reg1_type = STACK;
			default:
				io::printfn("ERROR: Unexpected identifier '%s' on token [%d] on line %d", tokens[*index].toString(), *index, tokens[*index].line);
				return ERROR;
		}

		(*index)++;

		if (tokenArgument(tokens, &argument, index)) {
			logistic.reg2_argument = argument;
			instruction.logistic = logistic;
			return TRUE;
		}
		else {
			io::printfn("ERROR: Unexpected identifier '%s' on token [%d] on line %d", tokens[*index].toString(), *index, tokens[*index].line);
			return ERROR;
		}
	}
	else {
		return FALSE;
	}
}

fn TokenValid tokenControlSwitch(List{Token} tokens, Instruction* instruction, uint* index) {
	instruction.type = CONTROL_SWITCH;

	String tok = tokens[*index].toString();
	upper(&tok);

	ControlSwitch control_switch;

	switch (tok) {
		case "JMP":
			control_switch.opcode = JMP;
		case "JE":
			control_switch.opcode = JE;
		case "JNE":
			control_switch.opcode = JNE;
		case "JG":
			control_switch.opcode = JG;
		case "JL":
			control_switch.opcode = JL;
		case "JGE":
			control_switch.opcode = JGE;
		case "JLE":
			control_switch.opcode = JLE;
		case "CALL":
			control_switch.opcode = CALL;
		default:
			return FALSE;
	}

	(*index)++;

	Argument argument;

	if (tokenArgument(tokens, &argument, index)) {
		control_switch.argument = argument;

		if (control_switch.opcode != JMP && control_switch.opcode != CALL) {
			if (tokens[*index].str[0] == ':' && is_alphanum(tokens[(usz)*index + 1])) {
				(*index)++;
				control_switch.label = tokens[*index].toString();
				//(*index)++;
			}
			else {
				io::printfn("ERROR: Expected a label at token [%d] on line %d.", *index, tokens[*index].line);
				return ERROR;
			}

			(*index)++;
		}

		instruction.control_switch = control_switch;
		return TRUE;
	}
	else {
		io::printfn("ERROR: Expected a register, literal, or label at token [%d] on line %d.", *index, tokens[*index].line);
		return ERROR;
	}


}

fn TokenValid tokenOther(List{Token} tokens, Instruction* instruction, uint* index) {
	instruction.type = OTHER;

	String tok = tokens[*index].toString();
	upper(&tok);

	Other other;

	switch (tok) {
		case "AND":
			other.opcode = AND;
		case "OR":
			other.opcode = OR;
		case "XOR":
			other.opcode = XOR;
		case "LOAD8":
			other.opcode = LOAD8;
		case "LOAD16":
			other.opcode = LOAD16;
		case "STORE8":
			other.opcode = STORE8;
		case "STORE16":
			other.opcode = STORE16;
		case "SYSCALL":
			other.opcode = SYSCALL;
		default:
			return FALSE;
	}

	(*index)++;

	Argument argument;

	if (tokenArgument(tokens, &argument, index)) {
		other.argument = argument;
		instruction.other = other;

		if (other.opcode == SYSCALL) {
			if (argument.type == LABEL) {
				io::printfn("ERROR: SYSCALL argument cannot be a label (line %d).", tokens[*index].line);
				return ERROR;
			}
		}
		
		return TRUE;
	}
	else {
		io::printfn("ERROR: Expected a register, literal, or label at token [%d] on line %d.", *index, tokens[*index].line);
		return ERROR;
	}
}

fn bool tokenInstruction(List{Token} tokens, Instruction* instruction, uint* index) {
	uint n_index1 = *index;
	uint n_index2 = *index;
	uint n_index3 = *index;
	uint n_index4 = *index;
	
	TokenValid arith = tokenArithmetic(tokens, instruction, &n_index1);
	if (arith == ERROR) {
		return false;
	}
	else if (arith == TRUE) {
		*index = n_index1;
	}
	else {
		TokenValid logi = tokenLogistic(tokens, instruction, &n_index2);

		if (logi == ERROR) {
			return false;
		}
		else if (logi == TRUE) {
			//io::printfn("INSTRIGFERGER: %s\n", instruction.type);
			*index = n_index2;
		}
		else {
			TokenValid cont = tokenControlSwitch(tokens, instruction, &n_index3);

			if (cont == ERROR) {
				return false;
			}
			else if (cont == TRUE) {
				*index = n_index3;
			}
			else {
				TokenValid oth = tokenOther(tokens, instruction, &n_index4);

				if (oth == ERROR) {
					return false;
				}
				else if (oth == TRUE) {
					*index = n_index4;
				}
				else {
					io::printfn("ERROR: Unexpected instruction '%s' on line %d.", tokens[*index].toString(), tokens[*index].line);
					return false;
				}
			}
		}
	}

	return true;
}

fn TokenValid tokenPreprocessorInstructionLabel(List{Token} tokens, List{PreprocessorInstructionLabel}* pil_list, uint index) {
	while (index < tokens.len()) {
		PreprocessorInstructionLabel pil;

		if (tokens[index].str[0] == '.') {
			index++;
			if (tokenPreprocessor(tokens, &pil, &index)) {
				pil_list.push(pil);

				if (pil.preprocessor_id.preprocessor_post.type == LABEL) {
					index++;
				}
			}
			else {
				io::printfn("ERROR: Unexpected token [%d] on line %d.", index, tokens[index].line);
				return ERROR;
			}
		}
		else if (tokens[index].str[0] == ':') {
			index++;
			
			if (tokenLabel(tokens, &pil, &index)) {
				pil_list.push(pil);
			}
			else {
				io::printfn("ERROR: Unexpected token [%d] on line %d.", index, tokens[index].line);
				return ERROR;
			}

			//index++;
		}
		else {
			pil.type = INSTRUCTION;
			Instruction instruction;

			if (tokenInstruction(tokens, &instruction, &index)) {
				pil.instruction_id = instruction;
				pil_list.push(pil);
			}
			else {
				return ERROR;
			}

			//index++;
			// Try arithmetic
			/*switch (tokens[index]) {
				
			}*/
		}
	}

	return TRUE;
}

fn bool parse(List{PreprocessorInstructionLabel}* pil, List{Token} tokens) {
	TokenValid valid = tokenPreprocessorInstructionLabel(tokens, pil, 0);

	/*if (valid == TRUE) {
		for (int i = 0; i < pil.len(); i++) {
			io::printfn("%s", (*pil)[i]);
		}
	}*/
	return valid != ERROR;
}

fn uint fnv_1a(String str) {
	uint hash = 0x811c9dc5;
	for (int i = 0; i < str.len; i++) {
		hash ^= str[i];
		hash *= 0x01000193;
	}

	return hash;
}

fn bool preprocess(List{PreprocessorInstructionLabel} pil, List{Label}* labels, List{PreprocessedInstruction}* instructions) {
	ushort current_addr = 0;

	for (int i = 0; i < pil.len(); i++) {
		switch (pil[i].type) {
			case PREPROCESSOR:
				Preprocessor preprocessor = pil[i].preprocessor_id;
				upper(&preprocessor.preprocessor_id);
				switch (preprocessor.preprocessor_id) {
					case "PUBLIC":
						if (preprocessor.preprocessor_post.type != LABEL) {
							io::printfn("ERROR: .PUBLIC expects a label on line %d.", i+1);
							return false;
						}

						// Ensure the label hasn't already been declared
						if (catch labelIn(*labels, preprocessor.preprocessor_post.label)) {
							// FNV-1a
							uint hash = fnv_1a(preprocessor.preprocessor_post.label);
							labels.push({.name = preprocessor.preprocessor_post.label, .offset = current_addr, .is_public = true, .hash = hash});
						}
						else {
							io::printfn("ERROR: Label '%s' has already been declared.", preprocessor.preprocessor_post.label);
							return false;
						}
					default:
						io::printfn("ERROR: Unrecognized preprocessor instruction '%s' on line %d.", pil[i].preprocessor_id, i+1);
						return false;
				}
			case INSTRUCTION:
				Instruction instruction = pil[i].instruction_id;
				instructions.push({.instruction = instruction, .address = current_addr, .requested_label1 = 0, .requested_label2 = 0, .has_label1 = false, .has_label2 = false});

				switch (instruction.type) {
					case ARITHMETIC:
						Arithmetic arith = instruction.arithmetic;

						switch (arith.argument.type) {
							case REGISTER:
								current_addr++;
							case LITERAL:
								if (arith.argument.literal >= -128 && arith.argument.literal < 127) {
									current_addr += 2;
								}
								else if (arith.argument.literal >= -32768 && arith.argument.literal < 32767) {
									current_addr += 3;
								}
								else {
									io::printfn("ERROR: Literal '%d' on line %d must be -128< and <127 or -32768< and <32767.", arith.argument.literal, i+1);
									return false;
								}
							case LABEL:
								current_addr += 3; // 1 byte for instruction, 2 for label
						}
					case LOGISTIC:
						Logistic log = instruction.logistic;

						switch (log.reg2_argument.type) {
							case REGISTER:
								current_addr++;
							case LITERAL:
								if (log.reg2_argument.literal >= -128 && log.reg2_argument.literal < 127) {
									current_addr += 2;
								}
								else if (log.reg2_argument.literal >= -32768 && log.reg2_argument.literal < 32767) {
									current_addr += 3;
								}
								else {
									io::printfn("ERROR: Literal '%d' on line %d must be -128< and <127 or -32768< and <32767.", log.reg2_argument.literal, i+1);
									return false;
								}
							case LABEL:
								current_addr += 3;
						}
					case CONTROL_SWITCH:
						ControlSwitch cont_sw = instruction.control_switch;

						switch (cont_sw.argument.type) {
							case REGISTER:
								if (cont_sw.opcode == JMP || cont_sw.opcode == CALL) {
									current_addr++;
								}
								else {
									current_addr += 3;
								}
							case LITERAL:
								nextcase;
							case LABEL:
								if (cont_sw.opcode == JMP || cont_sw.opcode == CALL) {
									current_addr += 3;
								}
								else {
									current_addr += 5;
								}
						}
					case OTHER:
						Other other = instruction.other;

						switch (other.argument.type) {
							case REGISTER:
								current_addr++;
							case LITERAL:
								if (other.argument.literal >= -128 && other.argument.literal < 127) {
									current_addr += 2;
								}
								else if (other.argument.literal >= -32768 && other.argument.literal < 32767) {
									current_addr += 3;
								}
								else {
									io::printfn("ERROR: Literal '%d' on line %d must be -128< and <127 or -32768< and <32767.", other.argument.literal, i+1);
									return false;
								}
							case LABEL:
								current_addr += 3;
						}
				}
			case LABEL:
				String label = pil[i].label_id;

				// Ensure the label hasn't already been declared
				if (catch labelIn(*labels, label)) {
					// FNV-1a
					labels.push({.name = label, .offset = current_addr, .is_public = false, .hash = fnv_1a(label)});
				}
				else {
					io::printfn("ERROR: Label '%s' has already been declared.", label);
					return false;
				}	
		}
	}

	return true;
}

faultdef NOT_FOUND;

fn usz? labelIn(List{Label} labels, String requested_label) {
	for (int i = 0; i < labels.len(); i++) {
		if (labels[i].name == requested_label) {
			return i;
		}
	}

	return NOT_FOUND~;
}

fn char resolve_argument(Argument arg) {
	switch (arg.type) {
		case REGISTER:
			// Could be more optimal with direct enum-to-int conversions
			return (char)arg.register;
		case LABEL:
			return 0b111;
		case LITERAL:
			if (arg.literal >= -128 && arg.literal <= 127) {
				return 0b110;
			}
			else {
				return 0b111;
			}
	}
}

fn void assemble(File f, List{Label} labels, List{PreprocessedInstruction} instructions) {
	// STRUCTURE OF OBJECT FILES:
	/*
		[0x0: u32 (4 bytes)] signature									The file signature (TISO -> TIS Object)
		[0x4: u16 (2 bytes)] number_of_exported_symbols					The number of provided/public/exported symbols defined in the file
		[0x6: u16 (2 bytes)] number_of_requested_symbols				The number of requested symbols defined externally

		[0x8: Exported Symbol Table * number_of_exported_symbols]
			[u32 (4 bytes)] hash										A hash of the symbol's name computed with 32-bit FNV-1a
			[u16 (2 bytes)] offset_location								The offset relative to the Data section representing a memory address.
			...

		[0x...: Requested Symbol Table * number_of_requested_symbols]
			[u32 (4 bytes)] hash										A hash of the requested symbol's name computed with 32-bit FNV-1a
			[u16 (2 bytes)] offset_location								The offset relative to this file's Data section pointing to a 2-byte memory section where the symbol is requested.
			...

		[0x... Data]
			Represents the data of the file, including static memory and instructions.

	*/

	f.write("TISO")!!; // TIS Object

	ushort number_of_exported_symbols = 0;
	for (int i = 0; i < labels.len(); i++) {
		if (labels[i].is_public) {
			number_of_exported_symbols++;
		}
	}

	f.write(((char*)&number_of_exported_symbols)[:2])!!;

	List{Symbol} requested_symbols;
	defer requested_symbols.free();

	char[] assembled_instructions = mem::new_array(char, instructions.len()*3);
	defer mem::free(assembled_instructions);

	for (int i = 0; i < instructions.len(); i++) {
		switch (instructions[i].instruction.type) {
			case ARITHMETIC:
				if (instructions[i].instruction.arithmetic.argument.type == LABEL) {
					usz? label_loc = labelIn(labels, instructions[i].instruction.arithmetic.argument.label);
					if (catch label_loc) {
						requested_symbols.push({.hash = fnv_1a(instructions[i].instruction.arithmetic.argument.label), .offset = instructions[i].address + 1});
					}
					else {
						instructions[i].requested_label1 = (short)labels[label_loc].offset - (short)instructions[i].address;
						instructions[i].has_label1 = true;
					}
				}
			case LOGISTIC:
				if (instructions[i].instruction.logistic.reg2_argument.type == LABEL) {
					usz? label_loc = labelIn(labels, instructions[i].instruction.logistic.reg2_argument.label);
					if (catch label_loc) {
						requested_symbols.push({.hash = fnv_1a(instructions[i].instruction.logistic.reg2_argument.label), .offset = instructions[i].address + 1});
					}
					else {
						instructions[i].requested_label1 = (short)labels[label_loc].offset - (short)instructions[i].address;
						instructions[i].has_label1 = true;
					}
				}
			case CONTROL_SWITCH:
				if (instructions[i].instruction.control_switch.argument.type == LABEL) {
					usz? label_loc = labelIn(labels, instructions[i].instruction.control_switch.argument.label);
					if (catch label_loc) {
						requested_symbols.push({.hash = fnv_1a(instructions[i].instruction.control_switch.argument.label), .offset = instructions[i].address + 1});
					}
					else {
						instructions[i].requested_label1 = (short)labels[label_loc].offset - (short)instructions[i].address;
						instructions[i].has_label1 = true;
					}
				}

				if (instructions[i].instruction.control_switch.opcode != JMP && instructions[i].instruction.control_switch.opcode != CALL) {
					usz? label_loc2 = labelIn(labels, instructions[i].instruction.control_switch.label);
					if (catch label_loc2) {
						requested_symbols.push({.hash = fnv_1a(instructions[i].instruction.control_switch.label), .offset = instructions[i].address + 3});
					}
					else {
						instructions[i].requested_label2 = (short)labels[label_loc2].offset - (short)instructions[i].address;
						instructions[i].has_label2 = true;
					}
				}

			case OTHER:
				if (instructions[i].instruction.other.argument.type == LABEL) {
					usz? label_loc = labelIn(labels, instructions[i].instruction.other.argument.label);
					if (catch label_loc) {
						requested_symbols.push({.hash = fnv_1a(instructions[i].instruction.other.argument.label), .offset = instructions[i].address + 1});
					}
					else {
						instructions[i].requested_label1 = (short)labels[label_loc].offset - (short)instructions[i].address;
						instructions[i].has_label1 = true;
					}
				}
		}
	}

	ushort requested_count = (ushort)requested_symbols.len();
	f.write(((char*)&requested_count)[:2])!!;

	// Write the exported symbols
	for (int i = 0; i < labels.len(); i++) {
		if (labels[i].is_public) {
			f.write(((char*)&labels[i].hash)[:4])!!;
			f.write(((char*)&labels[i].offset)[:2])!!;
		}
	}

	// Write the requested symbols
	for (int i = 0; i < requested_symbols.len(); i++) {
		f.write(((char*)&requested_symbols[i].hash)[:4])!!;
		f.write(((char*)&requested_symbols[i].offset)[:2])!!;
	}

	// Write the instructions
	for (int i = 0; i < instructions.len(); i++) {
		char binary = (char)instructions[i].instruction.type << 6;
		Argument arg;

		switch (instructions[i].instruction.type) {
			case ARITHMETIC:
				binary |= (char)instructions[i].instruction.arithmetic.opcode << 3;
				arg = instructions[i].instruction.arithmetic.argument;
			case LOGISTIC:
				binary |= (char)instructions[i].instruction.logistic.reg1_type << 3;
				arg = instructions[i].instruction.logistic.reg2_argument;
			case CONTROL_SWITCH:
				binary |= (char)instructions[i].instruction.control_switch.opcode << 3;
				arg = instructions[i].instruction.control_switch.argument;
			case OTHER:
				binary |= (char)instructions[i].instruction.other.opcode << 3;
				arg = instructions[i].instruction.other.argument;
		}

		char res = resolve_argument(arg);
		binary |= res;

		f.write_byte(binary)!!;

		if (instructions[i].has_label1) {
			f.write(((char*)&instructions[i].requested_label1)[:2])!!;
		}

		if (instructions[i].has_label2) {
			f.write(((char*)&instructions[i].requested_label2)[:2])!!;
		}

		if (res == 0b110) {
			f.write_byte((char)arg.literal)!!;
		}
		else if (res == 0b111) {
			// Annoying dumbass endian shit
			f.write_byte((char)arg.literal)!!;
			f.write_byte((char)((short)arg.literal >> 8))!!;
		}
	}
}

fn void main(String[] args) {
	if (args.len != 2) {
		io::printn("ERROR: Requires exactly 1 argument");
		return;
	}

	String file_data = (String)file::load_temp(args[1])!!;
	String[] lines = file_data.tsplit("\n");
	for (int i = 0; i < lines.len; i++) {
		lines[i] = lines[i].trim("\t ");
		replace(&lines[i], '\t', ' ');
		replace(&lines[i], ',', ' ');
	}

	/*for (int i = 0; i < lines.len; i++) {
		io::printfn("%s", lines[i]);
	}*/

	List{Token} tokens;
	tokens.init(mem);
	defer tokens.free();

	for (int i = 0; i < lines.len; i++) {
		if (lines[i] != "") {
			lex(&tokens, lines[i], i + 1);
		}
	}

	/*io::printfn("\n\nTOKENS: %d", tokens.len());
	for (int i = 0; i < tokens.len(); i++) {
		io::printfn("[%s]", (String)tokens[i].str[:tokens[i].len]);
	}*/

	//io::printn();

	List{PreprocessorInstructionLabel} pil;
	defer pil.free();
	
	if (parse(&pil, tokens)) {
		List{Label} labels;
		List{PreprocessedInstruction} instructions;
		defer labels.free();
		defer instructions.free();

		//io::printn();
		if (preprocess(pil, &labels, &instructions)) {
			io::printn("Labels:");
			for (int i = 0; i < labels.len(); i++) {
				io::printfn("\t[0x%X] %s, PUBLIC=%d", labels[i].offset, labels[i].name, labels[i].is_public);
			}

			io::printn("Instructions:");
			for (int i = 0; i < instructions.len(); i++) {
				io::printfn("\t[0x%X] %s", instructions[i].address, instructions[i].instruction);
			}

			usz index = args[1].rindex_of(".tis")!!;
			args[1][index+1] = 'o';
			args[1] = args[1][.. ^3];

			File out_file = file::open(args[1], "wb+")!!;
			defer out_file.close()!!;
			assemble(out_file, labels, instructions);
		}
	}
}