module tis::disassembler;

import std::io;
import std::io::file;

// STRUCTURE OF EXECUTABLE FILES:
/*
	[0x0: u32 (4 bytes)] signature									The file signature (TISE -> TIS Executable)
	[0x4: u16 (2 bytes)] entry_point								The offset into the Data section where the entry point of the executable is located (denoted .PUBLIC :MAIN)

	[0x6: Data]
		Represents the data of the file, including static memory and instructions.

*/

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

    for (int i = 0; i < code.len; i++) {
        io::printf("%X ", code[i]);
    }
    io::printn();

    // Set up program counter
    ushort program_counter = 0;//*(ushort*)&file_data[4];

    io::printfn("Entry Point: 0x%X", *(ushort*)&file_data[4]);
    io::printfn("Program Size: %d bytes", code.len);
    io::printn();

    while (program_counter < code.len) {
        char instruction = code[program_counter];

		io::printf("[0x%X] ", program_counter);

        // Decode instruction
        switch (instruction >> 6) {
            case 0b00:
                // Arithmetic
                switch ((instruction >> 3) & 0b111) {
                    case 0b000:
                        io::print("ADD ");
                    case 0b001:
                        io::print("SUB ");
                    case 0b010:
                        io::print("MUL ");
                    case 0b011:
                        io::print("DIV ");
                    case 0b100:
                        io::print("MOD ");
                    case 0b101:
                        io::print("SLL ");
                    case 0b110:
                        io::print("SRL ");
                    case 0b111:
                        io::print("NOT ");
                }

                switch (instruction & 0b111) {
                    case 0b000:
                        io::printn("NIL");
                    case 0b001:
                        io::printn("A");
                    case 0b010:
                        io::printn("B");
                    case 0b011:
                        io::printn("C");
                    case 0b100:
                        io::printn("D");
                    case 0b101:
                        io::printn("STACK");
                    case 0b110:
                        io::print("LITERAL8 [");
                        program_counter++;
                        io::printfn("%d]", mem::load((ichar*)&code[program_counter], 1)/**(char*)&code[program_counter]*/);
                    case 0b111:
                        io::print("LITERAL16 [");
                        program_counter++;
                        io::printfn("%d]", mem::load((short*)&code[program_counter], 1) /**(short*)&code[program_counter]*/);
                        program_counter++;
                };
            case 0b01:
                // Logistic
                io::print("MOV ");
                switch ((instruction >> 3) & 0b111) {
                    case 0b000:
                        io::print("NIL, ");
                    case 0b001:
                        io::print("A, ");
                    case 0b010:
                        io::print("B, ");
                    case 0b011:
                        io::print("C, ");
                    case 0b100:
                        io::print("D, ");
                    case 0b101:
                        io::print("STACK, ");
                    case 0b110:
                        nextcase;
                    case 0b111:
                        io::printn();
                        io::printfn("ERROR: [0x%X] MOV LITERAL, * not a valid instruction", program_counter);
                        return;
                };

                switch (instruction & 0b111) {
                    case 0b000:
                        io::printn("NIL");
                    case 0b001:
                        io::printn("A");
                    case 0b010:
                        io::printn("B");
                    case 0b011:
                        io::printn("C");
                    case 0b100:
                        io::printn("D");
                    case 0b101:
                        io::printn("STACK");
                    case 0b110:
                        io::print("LITERAL8 [");
                        program_counter++;
                        io::printfn("%d]", mem::load((ichar*)&code[program_counter], 1)/**(char*)&code[program_counter]*/);
                    case 0b111:
                        io::print("LITERAL16 [");
                        program_counter++;
                        io::printfn("%d]", mem::load((short*)&code[program_counter], 1)/**(short*)&code[program_counter]*/);
                        program_counter++;
                };
            case 0b10:
                // Control Switch
                switch ((instruction >> 3) & 0b111) {
                    case 0b000:
                        io::print("JMP ");
                    case 0b001:
                        io::print("JE ");
                    case 0b010:
                        io::print("JNE ");
                    case 0b011:
                        io::print("JG ");
                    case 0b100:
                        io::print("JL ");
                    case 0b101:
                        io::print("JGE ");
                    case 0b110:
                        io::print("JLE ");
                    case 0b111:
                        io::print("CALL ");
                }

                switch (instruction & 0b111) {
                    case 0b000:
                        io::print("NIL");
                    case 0b001:
                        io::print("A");
                    case 0b010:
                        io::print("B");
                    case 0b011:
                        io::print("C");
                    case 0b100:
                        io::print("D");
                    case 0b101:
                        io::print("STACK");
                    case 0b110:
                        io::print("LITERAL8 [");
                        program_counter++;
                        io::printf("%d]", mem::load((ichar*)&code[program_counter], 1)/**(char*)&code[program_counter]*/);

                        /*if ((instruction >> 3) & 0b111 == 0b000 || (instruction >> 3) & 0b111 == 0b111) {
                            io::printn();
                        }*/
                    case 0b111:
                        io::print("LITERAL16 [");
                        program_counter++;
                        io::printf("%d]", mem::load((short*)&code[program_counter], 1)/**(short*)&code[program_counter]*/);
                        program_counter++;

                        /*if ((instruction >> 3) & 0b111 == 0b000 || (instruction >> 3) & 0b111 == 0b111) {
                            io::printn();
                        }*/
                };

                if ((instruction >> 3) & 0b111 != 0b000 && (instruction >> 3) & 0b111 != 0b111) {
                    program_counter++;
                    io::printfn(", LITERAL16 [%d]", mem::load((short*)&code[program_counter], 1)/**(short*)&code[program_counter]*/);
                    program_counter++;
                }
                else {
                    io::printn();
                }


            case 0b11:
                // Other
                switch ((instruction >> 3) & 0b111) {
                    case 0b000:
                        io::print("AND ");
                    case 0b001:
                        io::print("OR ");
                    case 0b010:
                        io::print("XOR ");
                    case 0b011:
                        io::print("LOAD8 ");
                    case 0b100:
                        io::print("LOAD16 ");
                    case 0b101:
                        io::print("STORE8 ");
                    case 0b110:
                        io::print("STORE16 ");
                    case 0b111:
                        io::print("SYSCALL ");
                }

                switch (instruction & 0b111) {
                    case 0b000:
                        io::printn("NIL");
                    case 0b001:
                        io::printn("A");
                    case 0b010:
                        io::printn("B");
                    case 0b011:
                        io::printn("C");
                    case 0b100:
                        io::printn("D");
                    case 0b101:
                        io::printn("STACK");
                    case 0b110:
                        io::print("LITERAL8 [");
                        program_counter++;
                        io::printfn("%d]", mem::load((ichar*)&code[program_counter], 1)/**(char*)&code[program_counter]*/);
                    case 0b111:
                        io::print("LITERAL16 [");
                        program_counter++;
                        io::printfn("%d]", mem::load((short*)&code[program_counter], 1) /**(short*)&code[program_counter]*/);
                        program_counter++;
                };
        }

        program_counter++;
    }
}