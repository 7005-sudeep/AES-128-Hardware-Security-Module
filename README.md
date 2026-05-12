# AES-128-Hardware-Security-Module



Implemented AES-128 encryption engine in SystemVerilog (SubBytes, ShiftRows, MixColumns via GF(2⁸) xtime(),
AddRoundKey); deployed on Zybo Z7 achieving 125 MHz / 55-cycle / 440 ns latency.
• Resolved timing violation (WNS: −23.6 ns → −0.004 ns) by root-causing a 40-stage combinatorial key scheduler loop;
redesigned as 3-state sequential FSM and applied phys_opt_design / route_design TCL directives.
• Verified NIST FIPS-197 compliance using a 4-case self-checking testbench covering known-answer vectors, avalanche
effect, diffusion attack, and all-zeros edge case.
