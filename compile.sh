c3c compile tis_assembler.c3 tis_grammar.c3
c3c compile tis_linker.c3
c3c compile tis_disassembler.c3
c3c compile tis_runner.c3

./assembler ./sqrt.tis
./assembler ./main_sqrt.tis
./linker ./sqrt ./sqrt.o ./main_sqrt.o
./runner ./sqrt
