module tis::runner;

import std::io;
import std::io::file;
import std::collections;

// STRUCTURE OF EXECUTABLE FILES:
/*
	[0x0: u32 (4 bytes)] signature									The file signature (TISE -> TIS Executable)
	[0x4: u16 (2 bytes)] entry_point								The offset into the Data section where the entry point of the executable is located (denoted .PUBLIC :MAIN)

	[0x6: Data]
		Represents the data of the file, including static memory and instructions.

*/

alias RegGet = fn short(Register*);
alias RegSet = fn void(Register*, short);

struct Stack {
	short* stack;
	ushort index;
}

struct Register {
	void* val;
	RegGet get;
	RegSet set;
}

fn short getNil(Register* reg) {
	return 0;
}

fn void setNil(Register* reg, short new_val) {

}

fn short getA(Register* reg) {
	return *(short*)reg.val;
}

fn void setA(Register* reg, short new_val) {
	*(short*)reg.val = new_val;
}

fn short getB(Register* reg) {
	return *(short*)reg.val;
}

fn void setB(Register* reg, short new_val) {
	*(short*)reg.val = new_val;
}

fn short getC(Register* reg) {
	return *(short*)reg.val;
}

fn void setC(Register* reg, short new_val) {
	*(short*)reg.val = new_val;
}

fn short getD(Register* reg) {
	return *(short*)reg.val;
}

fn void setD(Register* reg, short new_val) {
	*(short*)reg.val = new_val;
}

fn short getStack(Register* reg) {
	Stack* s = (Stack*)reg.val;

	if (!s.index) {
		return 0;
	}

	return s.stack[--s.index];
}

fn void setStack(Register* reg, short new_val) {
	Stack* s = (Stack*)reg.val;
	s.stack[s.index++] = new_val;
}


fn void main(String[] args) {
    if (args.len != 2) {
        io::printfn("ERROR: Expected exactly 1 argument.");
        return;
    }

    String file_data = (String)file::load_temp(args[1])!!;
    io::printfn("File size: %d bytes", file_data.len);

    if (file_data[:4] != "TISE") {
        io::printfn("ERROR: Expected a TIS Executable.");
        return;
    }

    String code = file_data[6..];

	code = code.concat(mem, "0000");

    for (int i = 0; i < code.len; i++) {
        io::printf("%X ", code[i]);
    }
    io::printn();

    // Set up stack
    char[] stack_mem = mem::new_array(char, 65536);
    defer mem::free(stack_mem);

	Stack stack = {.stack = (short*)stack_mem.ptr, .index = 0};

	short register_a = 0;
	short register_b = 0;
	short register_c = 0;
	short register_d = 0;

	HashMap{char, Register} registers;
	registers.init(mem, 4);
	defer registers.free();

	registers[0b000] = {.val = null, .get = &getNil, .set = &setNil};
	registers[0b001] = {.val = &register_a, .get = &getA, .set = &setA};
	registers[0b010] = {.val = &register_b, .get = &getB, .set = &setB};
	registers[0b011] = {.val = &register_c, .get = &getC, .set = &setC};
	registers[0b100] = {.val = &register_d, .get = &getD, .set = &setD};
	registers[0b101] = {.val = &stack, .get = &getStack, .set = &setStack};

    // Set up program counter
    ushort program_counter = *(ushort*)&file_data[4];

    io::printfn("Entry Point: 0x%X", *(ushort*)&file_data[4]);
    io::printfn("Program Size: %d bytes", code.len);
    io::printn();

    while (program_counter < code.len) {
		io::printfn("Program Counter: 0x%X", program_counter);
        char instruction = code[program_counter];

		ushort val = 0;

        // Decode instruction
        switch (instruction >> 6) {
            case 0b00:
				if ((instruction & 0b111) == 0b110) {
					val = (short)(ichar)code[++program_counter];
					io::printn("LITERAL8");
				}
				else if ((instruction & 0b111) == 0b111) {
					io::printn("LITERAL16");
					val = mem::load((short*)&code[++program_counter], 1);
					program_counter++;
				}
				else {
					io::printn("REGISTER");
					Register* reg = &registers[instruction & 0b111];
					val = reg.get(reg);
				}
				io::printfn("VAL: %d", val);

                // Arithmetic
                switch ((instruction >> 3) & 0b111) {
                    case 0b000:
						// ADD
                        register_a += val;
                    case 0b001:
						// SUB
						register_a -= val;
                    case 0b010:
						// MUL
                        register_a *= val;
                    case 0b011:
						// DIV
                        register_a /= val;
                    case 0b100:
						// MOD
                        register_a %= val;
                    case 0b101:
						// SLL
                        register_a <<= val;
                    case 0b110:
						// SRL
                        register_a >>= val;
                    case 0b111:
						// NOT
                        register_a = ~val;
                }
            case 0b01:
			
				io::printfn("MOV: %b", instruction);

                // Logistic (MOV)
                if (instruction & 0b111 == 0b110) {
					val = (short)(ichar)code[++program_counter];
				}
				else if (instruction & 0b111 == 0b111) {
					val = mem::load((short*)&code[++program_counter], 1);
					program_counter++;
				}
				else {
					Register* reg = &registers[instruction & 0b111];
					val = reg.get(reg);
				}

				if ((instruction >> 3) & 0b111 == 0b110 || (instruction >> 3) & 0b111 == 0b111) {
					io::printfn("ERROR: [0x%X] MOV instruction cannot assign to a LITERAL8/LITERAL16.", program_counter);
					return;
				}

				Register* reg_assign = &registers[(instruction >> 3) & 0b111];
				reg_assign.set(reg_assign, val);
            case 0b10:
				if (instruction & 0b111 == 0b110) {
					val = (short)(ichar)code[++program_counter];
				}
				else if (instruction & 0b111 == 0b111) {
					val = mem::load((short*)&code[++program_counter], 1);
					program_counter++;
				}
				else {
					Register* reg = &registers[instruction & 0b111];
					val = reg.get(reg);
					program_counter++;
				}

				Register* reg_a = &registers[0b001];

				short new_addr = mem::load((short*)&code[program_counter], 1) - 1;
				
				io::printfn("NEW ADDR: 0x%X", new_addr);

                // Control Switch
                switch ((instruction >> 3) & 0b111) {
                    case 0b000:
						// Special case for stack hack (immediate addressing for JMP rather than relative)
						// JMP
						if (instruction & 0b111 == 0b101) {
							io::printfn("STACK ADDR: 0x%X", val);
							program_counter = val - 1; // -1 to allow for PC offset at end of loop
						}
						else {
							program_counter = (ushort)((short)program_counter + val - 1);
						}
                    case 0b001:
						// JE
                        if (val == register_a) {
							program_counter = (ushort)((short)program_counter + new_addr - 1);
						}
						else {
							program_counter++;
						}
                    case 0b010:
						// JNE
                        if (val != register_a) {
							program_counter = (ushort)((short)program_counter + new_addr - 1);
						}
						else {
							program_counter++;
						}
                    case 0b011:
						// JG
                        if (val < register_a) {
							program_counter = (ushort)((short)program_counter + new_addr - 1);
						}
						else {
							program_counter++;
						}
                    case 0b100:
						// JL
                        if (val > register_a) {
							program_counter = (ushort)((short)program_counter + new_addr - 1);
						}
                    case 0b101:
						// JGE
                        if (val <= register_a) {
							program_counter = (ushort)((short)program_counter + new_addr - 1);
						}
						else {
							program_counter++;
						}
                    case 0b110:
						// JLE
                        if (val >= register_a) {
							program_counter = (ushort)((short)program_counter + new_addr - 1);
						}
						else {
							program_counter++;
						}
                    case 0b111:
						// CALL
						ushort temp_addr = program_counter;
						if (instruction & 0b111 == 0b110) {
							//temp_addr++;
						}
						else if (instruction & 0b111 == 0b111) {
							temp_addr += 1;//2;
						}

						Register* _stack = &registers[0b101];
						io::printfn("TEMP_ADDR: 0x%X", temp_addr);
						_stack.set(_stack, temp_addr);
						program_counter = (ushort)((short)program_counter + val - 2);
                        io::printn("CALL");
                }

				io::printfn("New Program Counter: 0x%X", program_counter);

            case 0b11:
				if (instruction & 0b111 == 0b110) {
					val = (short)(ichar)code[++program_counter];
				}
				else if (instruction & 0b111 == 0b111) {
					val = mem::load((short*)&code[++program_counter], 1);
					program_counter++;
				}
				else {
					Register* reg = &registers[instruction & 0b111];
					val = reg.get(reg);
				}

                // Other
                switch ((instruction >> 3) & 0b111) {
                    case 0b000:
						// AND
                        register_a &= val;
                    case 0b001:
						// OR
                        register_a |= val;
                    case 0b010:
						// XOR
                        register_a ^= val;
                    case 0b011:
						// LOAD8
                        register_a = (short)(ichar)code[program_counter + val];
                    case 0b100:
						// LOAD16
                        register_a = mem::load((short*)&code[program_counter + val], 1);
                    case 0b101:
						// STORE8
                        code[program_counter + val] = (char)register_a;
                    case 0b110:
						// STORE16
                        mem::store((short*)&code[program_counter + val], register_a, 1);
                    case 0b111:
						// SYSCALL
                        io::print("SYSCALL ");
                }
        }

		io::printfn("A: %d\nB: %d\nC: %d\nD: %d\n", register_a, register_b, register_c, register_d);
        program_counter++;
    }
}