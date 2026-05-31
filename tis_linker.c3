module tis::linker;

import std::io;
import std::io::file;
import std::collections;
import std::core::mem;

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

// =========================================================================================================================================

// STRUCTURE OF EXECUTABLE FILES:
/*
	[0x0: u32 (4 bytes)] signature									The file signature (TISE -> TIS Executable)
	[0x2: u16 (2 bytes)] entry_point								The offset into the Data section where the entry point of the executable is located (denoted .PUBLIC :MAIN)

	[0x... Data]
		Represents the data of the file, including static memory and instructions.

*/

struct Symbol @packed {
	uint hash;
	ushort offset;
}

fn void main(String[] args) {
	// First arg is the out file

	if (args.len < 3) {
		io::printn("ERROR: 2 or more args required.");
		return;
	}

	String[] files = mem::new_array(String, args.len - 2);
	defer mem::free(files);

	for (int i = 0; i < args.len - 2; i++) {
		files[i] = (String)file::load_temp(args[i + 2])!!;
	}

	HashMap{uint, ushort} exported_symbols; // [hash]: offset
	exported_symbols.init(mem, 32);
	defer exported_symbols.free();

	List{Symbol} requested_symbols;
	defer requested_symbols.free();

	// Load Symbols
	ushort current_addr = 0;
	for (int i = 0; i < files.len; i++) {
		String file_data = files[i];

		if (file_data[:4] != "TISO") {
			io::printfn("ERROR: File '%s' is not a valid TIS Object File!", args[i + 2]);
			return;
		}

		ushort number_of_exported_symbols = *(ushort*)&file_data[4];
		ushort number_of_requested_symbols = *(ushort*)&file_data[6];

		io::printfn("File '%s': %d exported symbols, %d requested symbols.", args[i + 2], number_of_exported_symbols, number_of_requested_symbols);

		for (int j = 0; j < number_of_exported_symbols; j++) {
			Symbol s = *(Symbol*)&file_data[8 + j*Symbol.sizeof];
			uint hash = s.hash;
			if (!exported_symbols.has_key(hash)) {
				exported_symbols[hash] = s.offset + current_addr;
				io::printfn("Hash 0x%X: Original Offset %d, Final Offset %d", hash, s.offset, s.offset + current_addr);
			}
			else {
				io::printfn("ERROR: Symbol '0x%X' already defined.", s.hash);
				return;
			}
		}

		for (int j = 0; j < number_of_requested_symbols; j++) {
			Symbol s = mem::load((Symbol*)&file_data[(ulong)8 + (ulong)number_of_exported_symbols*6 + j*Symbol.sizeof], 1);
			requested_symbols.push({.hash = s.hash, .offset = s.offset + current_addr});
			io::printfn("Req: %d", s.offset);
		}

		io::printfn("Data Size: %d", (ushort)file_data.len - 8 - 6*number_of_exported_symbols - 6*number_of_requested_symbols);
		current_addr += (ushort)file_data.len - 8 - 6*number_of_exported_symbols - 6*number_of_requested_symbols; // Size of Data section
	}

	// 0x96272888 == MAIN
	if (!exported_symbols.has_key(0x96272888)) {
		io::printfn("ERROR: Symbol 'MAIN' not found -- required for entry point.");
		return;
	}

	// Accumulate all of the executable data together
	String code = (String)mem::new_array(char, 0);
	defer mem::free(code);

	for (int i = 0; i < files.len; i++) {
		String file_data = files[i];

		ushort number_of_exported_symbols = *(ushort*)&file_data[4];
		ushort number_of_requested_symbols = *(ushort*)&file_data[6];

		io::printfn("File '%s': %d bytes", args[i + 2], files[i].len);
		code = code.concat(mem, files[i][8 + 6*number_of_exported_symbols + 6*number_of_requested_symbols..]);
	}

	io::printfn("Final size: %d", code.len);

	// Resolve Symbols
	for (int i = 0; i < requested_symbols.len(); i++) {
		if (exported_symbols.has_key(requested_symbols[i].hash)) {
			io::printfn("Location: %d", (short)exported_symbols[requested_symbols[i].hash]!!);
			io::printfn("Offset: %d", requested_symbols[i].offset);
			short diff = (short)exported_symbols[requested_symbols[i].hash]!! - (short)requested_symbols[i].offset;
			mem::store((short*)&code[requested_symbols[i].offset], diff, 1);
			//*(short*)&code[requested_symbols[i].offset] = (short)exported_symbols[requested_symbols[i].hash]!! - (short)requested_symbols[i].offset;
			break;
		}
		else {
			io::printfn("ERROR: Symbol 0x%X not found!", requested_symbols[i].hash);
			return;
		}
	}

	File f = file::open(args[1], "wb+")!!;
	f.write("TISE")!!;
	f.write(((char*)&exported_symbols[0x96272888])[:2])!!;
	f.write(code)!!;
}