# TransistorU 
A Tomasulo based RISC-V CPU supporting partial of rv32i ISA.

<img src="https://media.52poke.com/wiki/9/96/Spr_8s_894.png">

## Technical Specifications
- Tomasulo algorithm with Reorder Buffer.
- Support 2-bit saturating counter branch prediction of 256 entries. 
- Directed-mapped I-cache of 128 entries.
- Reorder Buffer of 16 entries.

## Running Status
- Passing all testcases in simulation.
- Running on XC7A35T-ICPG236C FPGA board with all testcases passed.
