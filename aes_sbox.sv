// =============================================================================
// File        : aes_sbox.sv
// Project     : AES-128 Hardware Security Module (HSM)
// Description : NIST-compliant AES SubBytes look-up table.
//               Synchronous ROM (inferred BRAM or LUT-RAM).
// =============================================================================

module aes_sbox (
    input  logic       clk,
    input  logic [7:0] addr,
    output logic [7:0] dout
);

    // AES Forward S-Box
    logic [7:0] SBOX [0:255];

    initial begin
        SBOX[  0]=8'h63; SBOX[  1]=8'h7c; SBOX[  2]=8'h77; SBOX[  3]=8'h7b;
        SBOX[  4]=8'hf2; SBOX[  5]=8'h6b; SBOX[  6]=8'h6f; SBOX[  7]=8'hc5;
        SBOX[  8]=8'h30; SBOX[  9]=8'h01; SBOX[ 10]=8'h67; SBOX[ 11]=8'h2b;
        SBOX[ 12]=8'hfe; SBOX[ 13]=8'hd7; SBOX[ 14]=8'hab; SBOX[ 15]=8'h76;
        SBOX[ 16]=8'hca; SBOX[ 17]=8'h82; SBOX[ 18]=8'hc9; SBOX[ 19]=8'h7d;
        SBOX[ 20]=8'hfa; SBOX[ 21]=8'h59; SBOX[ 22]=8'h47; SBOX[ 23]=8'hf0;
        SBOX[ 24]=8'had; SBOX[ 25]=8'hd4; SBOX[ 26]=8'ha2; SBOX[ 27]=8'haf;
        SBOX[ 28]=8'h9c; SBOX[ 29]=8'ha4; SBOX[ 30]=8'h72; SBOX[ 31]=8'hc0;
        SBOX[ 32]=8'hb7; SBOX[ 33]=8'hfd; SBOX[ 34]=8'h93; SBOX[ 35]=8'h26;
        SBOX[ 36]=8'h36; SBOX[ 37]=8'h3f; SBOX[ 38]=8'hf7; SBOX[ 39]=8'hcc;
        SBOX[ 40]=8'h34; SBOX[ 41]=8'ha5; SBOX[ 42]=8'he5; SBOX[ 43]=8'hf1;
        SBOX[ 44]=8'h71; SBOX[ 45]=8'hd8; SBOX[ 46]=8'h31; SBOX[ 47]=8'h15;
        SBOX[ 48]=8'h04; SBOX[ 49]=8'hc7; SBOX[ 50]=8'h23; SBOX[ 51]=8'hc3;
        SBOX[ 52]=8'h18; SBOX[ 53]=8'h96; SBOX[ 54]=8'h05; SBOX[ 55]=8'h9a;
        SBOX[ 56]=8'h07; SBOX[ 57]=8'h12; SBOX[ 58]=8'h80; SBOX[ 59]=8'he2;
        SBOX[ 60]=8'heb; SBOX[ 61]=8'h27; SBOX[ 62]=8'hb2; SBOX[ 63]=8'h75;
        SBOX[ 64]=8'h09; SBOX[ 65]=8'h83; SBOX[ 66]=8'h2c; SBOX[ 67]=8'h1a;
        SBOX[ 68]=8'h1b; SBOX[ 69]=8'h6e; SBOX[ 70]=8'h5a; SBOX[ 71]=8'ha0;
        SBOX[ 72]=8'h52; SBOX[ 73]=8'h3b; SBOX[ 74]=8'hd6; SBOX[ 75]=8'hb3;
        SBOX[ 76]=8'h29; SBOX[ 77]=8'he3; SBOX[ 78]=8'h2f; SBOX[ 79]=8'h84;
        SBOX[ 80]=8'h53; SBOX[ 81]=8'hd1; SBOX[ 82]=8'h00; SBOX[ 83]=8'hed;
        SBOX[ 84]=8'h20; SBOX[ 85]=8'hfc; SBOX[ 86]=8'hb1; SBOX[ 87]=8'h5b;
        SBOX[ 88]=8'h6a; SBOX[ 89]=8'hcb; SBOX[ 90]=8'hbe; SBOX[ 91]=8'h39;
        SBOX[ 92]=8'h4a; SBOX[ 93]=8'h4c; SBOX[ 94]=8'h58; SBOX[ 95]=8'hcf;
        SBOX[ 96]=8'hd0; SBOX[ 97]=8'hef; SBOX[ 98]=8'haa; SBOX[ 99]=8'hfb;
        SBOX[100]=8'h43; SBOX[101]=8'h4d; SBOX[102]=8'h33; SBOX[103]=8'h85;
        SBOX[104]=8'h45; SBOX[105]=8'hf9; SBOX[106]=8'h02; SBOX[107]=8'h7f;
        SBOX[108]=8'h50; SBOX[109]=8'h3c; SBOX[110]=8'h9f; SBOX[111]=8'ha8;
        SBOX[112]=8'h51; SBOX[113]=8'ha3; SBOX[114]=8'h40; SBOX[115]=8'h8f;
        SBOX[116]=8'h92; SBOX[117]=8'h9d; SBOX[118]=8'h38; SBOX[119]=8'hf5;
        SBOX[120]=8'hbc; SBOX[121]=8'hb6; SBOX[122]=8'hda; SBOX[123]=8'h21;
        SBOX[124]=8'h10; SBOX[125]=8'hff; SBOX[126]=8'hf3; SBOX[127]=8'hd2;
        SBOX[128]=8'hcd; SBOX[129]=8'h0c; SBOX[130]=8'h13; SBOX[131]=8'hec;
        SBOX[132]=8'h5f; SBOX[133]=8'h97; SBOX[134]=8'h44; SBOX[135]=8'h17;
        SBOX[136]=8'hc4; SBOX[137]=8'ha7; SBOX[138]=8'h7e; SBOX[139]=8'h3d;
        SBOX[140]=8'h64; SBOX[141]=8'h5d; SBOX[142]=8'h19; SBOX[143]=8'h73;
        SBOX[144]=8'h60; SBOX[145]=8'h81; SBOX[146]=8'h4f; SBOX[147]=8'hdc;
        SBOX[148]=8'h22; SBOX[149]=8'h2a; SBOX[150]=8'h90; SBOX[151]=8'h88;
        SBOX[152]=8'h46; SBOX[153]=8'hee; SBOX[154]=8'hb8; SBOX[155]=8'h14;
        SBOX[156]=8'hde; SBOX[157]=8'h5e; SBOX[158]=8'h0b; SBOX[159]=8'hdb;
        SBOX[160]=8'he0; SBOX[161]=8'h32; SBOX[162]=8'h3a; SBOX[163]=8'h0a;
        SBOX[164]=8'h49; SBOX[165]=8'h06; SBOX[166]=8'h24; SBOX[167]=8'h5c;
        SBOX[168]=8'hc2; SBOX[169]=8'hd3; SBOX[170]=8'hac; SBOX[171]=8'h62;
        SBOX[172]=8'h91; SBOX[173]=8'h95; SBOX[174]=8'he4; SBOX[175]=8'h79;
        SBOX[176]=8'he7; SBOX[177]=8'hc8; SBOX[178]=8'h37; SBOX[179]=8'h6d;
        SBOX[180]=8'h8d; SBOX[181]=8'hd5; SBOX[182]=8'h4e; SBOX[183]=8'ha9;
        SBOX[184]=8'h6c; SBOX[185]=8'h56; SBOX[186]=8'hf4; SBOX[187]=8'hea;
        SBOX[188]=8'h65; SBOX[189]=8'h7a; SBOX[190]=8'hae; SBOX[191]=8'h08;
        SBOX[192]=8'hba; SBOX[193]=8'h78; SBOX[194]=8'h25; SBOX[195]=8'h2e;
        SBOX[196]=8'h1c; SBOX[197]=8'ha6; SBOX[198]=8'hb4; SBOX[199]=8'hc6;
        SBOX[200]=8'he8; SBOX[201]=8'hdd; SBOX[202]=8'h74; SBOX[203]=8'h1f;
        SBOX[204]=8'h4b; SBOX[205]=8'hbd; SBOX[206]=8'h8b; SBOX[207]=8'h8a;
        SBOX[208]=8'h70; SBOX[209]=8'h3e; SBOX[210]=8'hb5; SBOX[211]=8'h66;
        SBOX[212]=8'h48; SBOX[213]=8'h03; SBOX[214]=8'hf6; SBOX[215]=8'h0e;
        SBOX[216]=8'h61; SBOX[217]=8'h35; SBOX[218]=8'h57; SBOX[219]=8'hb9;
        SBOX[220]=8'h86; SBOX[221]=8'hc1; SBOX[222]=8'h1d; SBOX[223]=8'h9e;
        SBOX[224]=8'he1; SBOX[225]=8'hf8; SBOX[226]=8'h98; SBOX[227]=8'h11;
        SBOX[228]=8'h69; SBOX[229]=8'hd9; SBOX[230]=8'h8e; SBOX[231]=8'h94;
        SBOX[232]=8'h9b; SBOX[233]=8'h1e; SBOX[234]=8'h87; SBOX[235]=8'he9;
        SBOX[236]=8'hce; SBOX[237]=8'h55; SBOX[238]=8'h28; SBOX[239]=8'hdf;
        SBOX[240]=8'h8c; SBOX[241]=8'ha1; SBOX[242]=8'h89; SBOX[243]=8'h0d;
        SBOX[244]=8'hbf; SBOX[245]=8'he6; SBOX[246]=8'h42; SBOX[247]=8'h68;
        SBOX[248]=8'h41; SBOX[249]=8'h99; SBOX[250]=8'h2d; SBOX[251]=8'h0f;
        SBOX[252]=8'hb0; SBOX[253]=8'h54; SBOX[254]=8'hbb; SBOX[255]=8'h16;
    end

    always_ff @(posedge clk) begin
        dout <= SBOX[addr];
    end

endmodule
