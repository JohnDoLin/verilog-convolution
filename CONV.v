module  CONV(
	input			clk,
	input			rst_n,
	input 			mode,
	input       	in_valid,
	output  		out_valid,
	output 	[13:0] 	AWADDR,
	output	[7:0] 	AWLEN,
	output 			AWVALID,
	input 			AWREADY,
	output 	[31:0] 	WDATA,
	output 			WVALID,
	input 			WREADY,
	output 	[13:0] 	ARADDR,
	output 	[7:0] 	ARLEN,
	output 			ARVALID,
	input 			ARREADY,
	input	[31:0] 	RDATA,
	input 			RVALID,
	output 			RREADY
);

localparam 	[31:0]	bias = 32'h00001310;

integer i;

reg	[31:0]	mem_r [260:0], mem_w [260:0];
reg	[31:0]	buff_r [15:0], buff_w [15:0];
reg	[31:0]	pool_r	[31:0], pool_w [31:0];
reg	[12:0]	mem_cnt_r, mem_cnt_w;
reg	[12:0]	buff_push_cnt_r, buff_push_cnt_w;
reg	[12:0]	buff_pop_cnt_r, buff_pop_cnt_w;
reg	[4:0]	buff_pnt_r, buff_pnt_w;
reg	[10:0]	pool_shift_cnt_r, pool_shift_cnt_w;
reg	[10:0]	pool_cyc_cnt_r, pool_cyc_cnt_w;
reg	[3:0]	ar_addr_r, ar_addr_w;
reg	[4:0]	aw_addr0_r, aw_addr0_w;
reg	[4:0]	aw_addr1_r, aw_addr1_w;
reg	ar_valid_r, ar_valid_w;
reg	aw_valid_r, aw_valid_w;
reg	w_switch_w, w_switch_r;
reg	aw_switch_w, aw_switch_r;
reg	mode_w, mode_r;
reg	delayer;
reg	[31:0]	prods_w	[8:0], prods_r	[8:0];
reg	[12:0]	prods_cnt_w, prods_cnt_r;
reg	prods_valid_r, prods_valid_w;

wire	prods_left_in;
wire	prods_right_in;
wire	r_success;
wire	w_success;
wire	mem_shift;
wire	[31:0]	mem_out;
wire	[31:0]	buff_in;
wire	[31:0]	buff_out;
wire	buff_push;
wire	buff_pop;
wire	buff_full;
wire	buff_empty;
wire	buff_error;
wire	[31:0]	pool_in;
wire	[31:0]	pool_out;
wire	pool_cyc;
wire	pool_shift;
wire	is_at_buff;
wire	prods_calc;
wire	prods_valid;
wire	prods_devalid;

assign	ARLEN = 8'b11111111;
assign	ARADDR = {2'b0, ar_addr_r, 8'b0};
assign	ARVALID = ar_valid_r;
assign	AWLEN = (aw_switch_r == 1'b0) ? 7'b1111111 : 5'b11111;
assign	AWADDR = (aw_switch_r == 1'b0) ? {2'b01, aw_addr0_r, 7'b0} : {4'b1000, aw_addr1_r, 5'b0};
assign	AWVALID = aw_valid_r;
assign	RREADY = !buff_full;// && !prods_valid;
assign	WDATA = (w_switch_r == 1'b0) ? buff_out : pool_out;
assign	WVALID = w_switch_r ? 1'b1 : !buff_empty;
assign	r_success = RVALID & RREADY;
assign	w_success = WVALID & WREADY;
assign	out_valid = pool_shift_cnt_r[10];
assign	is_at_buff = mode_r ? (mem_cnt_r >= 131) : (mem_cnt_r >= 66);

assign	mem_shift = prods_valid && !buff_full;
assign	mem_out = (mem_r[0][31]) ? 32'b0 : mem_r[0];

assign	buff_in = mem_out;
assign	buff_out = (buff_empty) ? 32'b0 : buff_r[buff_pnt_r];
assign	buff_push = mem_shift && is_at_buff;
assign	buff_pop = w_success && !w_switch_r;
assign	buff_full = (buff_pnt_r == 5'b00000);
assign	buff_empty = (buff_pnt_r == 5'b10000);
assign	buff_error = (buff_empty && buff_pop) || (buff_full && !buff_pop && buff_push);
assign	pool_in = buff_out;
assign	pool_out = pool_r[0];
assign	pool_cyc = is_at_buff && (w_switch_r ? 1'b0 : buff_pop);
assign	pool_shift = w_success && w_switch_r;

assign	prods_left_in = mode_r ? ((prods_cnt_r[5:0] != 6'b0) && (prods_cnt_r[5:0] != 6'h01)) : (prods_cnt_r[5:0] != 6'b0);
assign	prods_right_in = mode_r ? ((prods_cnt_r[5:0] != 6'h3f) && (prods_cnt_r[5:0] != 6'h3e)) : (prods_cnt_r[5:0] != 6'h3f);
assign	prods_calc = r_success || (prods_cnt_r[12] && !buff_pop_cnt_r[12] && !buff_full);
assign	prods_valid = prods_valid_r;
assign	prods_devalid = mem_shift;

// delayer
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) delayer <= 1'b0;
	else delayer <= 1'b1;
end

// w_swich_w
always@(*) begin
	if(w_switch_r == 1'b0 && buff_pop_cnt_r[6:0] == 7'h7f && w_success) w_switch_w = 1'b1;
	else if(w_switch_r == 1'b1 && pool_shift_cnt_r[4:0] == 5'h1f && w_success) w_switch_w = 1'b0;
	else w_switch_w = w_switch_r;
end

// ar_valid_w
always@(*) begin
	if(ARVALID && ARREADY && (ar_addr_r == 4'b1111)) ar_valid_w = 1'b0;
	else ar_valid_w = ar_valid_r;
end

// ar_addr_w
always@(*) begin
	if(ARVALID && ARREADY) ar_addr_w = ar_addr_r + 1;
	else ar_addr_w = ar_addr_r;
end

// aw_valid_w
always@(*) begin
	if(AWVALID && AWREADY && aw_switch_r == 1'b1 && (aw_addr1_r == 5'h1f)) aw_valid_w = 1'b0;
	else aw_valid_w = aw_valid_r;
end

// aw_switch_w
always@(*) begin
	if(AWVALID && AWREADY) aw_switch_w = !aw_switch_r;
	else aw_switch_w = aw_switch_r;
end

// aw_addr0_w
always@(*) begin
	if(AWREADY && AWVALID && aw_switch_r == 1'b0) aw_addr0_w = aw_addr0_r+1;
	else aw_addr0_w = aw_addr0_r;
end

// aw_addr1_w
always@(*) begin
	if(AWREADY && AWVALID && aw_switch_r == 1'b1) aw_addr1_w = aw_addr1_r+1;
	else aw_addr1_w = aw_addr1_r;
end

// mode_w
always@(*) begin
	if(in_valid) mode_w = mode;
	else mode_w = mode_r;
end

//////// HARDWARE ///////

// prods_w
always@(*) begin
	if(prods_calc) begin
		prods_w[8] = (prods_right_in && !prods_cnt_r[12]) ? RDATA[23:16] * {20'hfffff, 20'hABC2E} : 32'b0;
		prods_w[7] = (!prods_cnt_r[12]) ? RDATA[23:16] * {20'hfffff, 20'hB52E2} : 32'b0;
		prods_w[6] = (prods_left_in && !prods_cnt_r[12]) ? RDATA[23:16] * {20'hfffff, 20'hAF5C4} : 32'b0;
		prods_w[5] = (prods_right_in && !prods_cnt_r[12]) ? RDATA[23:16] * {20'hfffff, 20'hE5518} : 32'b0;
		prods_w[4] = (!prods_cnt_r[12]) ? RDATA[23:16] * {20'h00000, 20'h71650} : 32'b0;
		prods_w[3] = (prods_left_in && !prods_cnt_r[12]) ? RDATA[23:16] * {20'hfffff, 20'hA938B} : 32'b0;
		prods_w[2] = (prods_right_in && !prods_cnt_r[12]) ? RDATA[23:16] * {20'h00000, 20'h5251F} : 32'b0;
		prods_w[1] = (!prods_cnt_r[12]) ? RDATA[23:16] * {20'h00000, 20'h7DFC0} : 32'b0;
		prods_w[0] = (prods_left_in && !prods_cnt_r[12]) ? RDATA[23:16] * {20'hfffff, 20'hEB885} : 32'b0;
	end else begin
		for(i=0;i<9;i=i+1) prods_w[i] = prods_r[i];
	end
	
end

// prods_cnt_w
always@(*) begin
	if(prods_calc) prods_cnt_w = prods_cnt_r + 1;
	else prods_cnt_w = prods_cnt_r;
	
end

// prods_valid_w
always@(*) begin
	if((prods_calc && prods_valid && !prods_devalid) || !prods_calc && !prods_valid && prods_devalid) prods_valid_w = prods_valid_r;
	else prods_valid_w = prods_valid_r + prods_calc + prods_devalid;
end

// mem_w
always@(*) begin
	if(mem_shift) begin
		if(mode_r == 1'b0) begin
			mem_w[0] = mem_r[1] + bias + prods_r[0];
			mem_w[1] = mem_r[2] + prods_r[1];
			mem_w[2] = mem_r[3] + prods_r[2];
			for(i=3;i<64;i=i+1) mem_w[i] = mem_r[i+1];
			mem_w[64] = mem_r[65] + prods_r[3];
			mem_w[65] = mem_r[66] + prods_r[4];
			mem_w[66] = mem_r[67] + prods_r[5];
			for(i=67;i<128;i=i+1) mem_w[i] = mem_r[i+1];
			mem_w[128] = mem_r[129] + prods_r[6];
			mem_w[129] = mem_r[130] + prods_r[7];
			mem_w[130] = prods_r[8];
			for(i=131;i<261;i=i+1) mem_w[i] = mem_r[i];
		end else begin
			mem_w[0] = mem_r[1] + bias + prods_r[0];
			mem_w[1] = mem_r[2];
			mem_w[2] = mem_r[3] +prods_r[1];
			mem_w[3] = mem_r[4];
			mem_w[4] = mem_r[5] + prods_r[2];
			for(i=5;i<128;i=i+1) mem_w[i] = mem_r[i+1];
			mem_w[128] = mem_r[129] + prods_r[3];
			mem_w[129] = mem_r[130];
			mem_w[130] = mem_r[131] + prods_r[4];
			mem_w[131] = mem_r[132];
			mem_w[132] = mem_r[133] + prods_r[5];
			for(i=133;i<256;i=i+1) mem_w[i] = mem_r[i+1];
			mem_w[256] = mem_r[257] + prods_r[6];
			mem_w[257] = mem_r[258];
			mem_w[258] = mem_r[259] + prods_r[7];
			mem_w[259] = mem_r[260];
			mem_w[260] = prods_r[8];
		end
	end else begin
		for(i=0;i<261;i=i+1) mem_w[i] = mem_r[i];
	end
end

// mem_cnt_w
always@(*) begin
	if(mem_shift) mem_cnt_w = mem_cnt_r+1;
	else mem_cnt_w = mem_cnt_r;
end

// buff_push_cnt_w
always@(*) begin
	if(buff_push) buff_push_cnt_w = buff_push_cnt_r+1;
	else buff_push_cnt_w = buff_push_cnt_r;
end

// buff_pop_cnt_w
always@(*) begin
	if(buff_pop) buff_pop_cnt_w = buff_pop_cnt_r+1;
	else buff_pop_cnt_w = buff_pop_cnt_r;
end

// buff_pnt_w
// Constraints: Do not pop when it is empty even with a push request. However, you can
// push and pull at the same time if the buffer is full. 
always@(*) begin
	if((buff_empty && buff_pop) || (buff_full && !buff_pop && buff_push)) begin
		buff_pnt_w = buff_pnt_r;
	end else begin
		buff_pnt_w = buff_pnt_r - buff_push + buff_pop;
	end
end

// buff_w
always@(*) begin
	if(buff_push) begin
		buff_w[15] = buff_in;
		for(i=0;i<15;i=i+1) buff_w[i] = buff_r[i+1];
	end else begin
		for(i=0;i<16;i=i+1) buff_w[i] = buff_r[i];
	end
end

// pool_shift_cnt_w
always@(*) begin
	if(pool_shift) pool_shift_cnt_w = pool_shift_cnt_r+1;
	else pool_shift_cnt_w = pool_shift_cnt_r;
end

// pool_cyc_cnt_w
always@(*) begin
	if(pool_cyc) pool_cyc_cnt_w = pool_cyc_cnt_r+1;
	else pool_cyc_cnt_w = pool_cyc_cnt_r;
end

// pool_w
// Constraints: Do not cyc and shift at the same time.
// Function: When cyc, if pool_cyc_cnt_r is even then it dotn't cyc and just
// take the max, and do both when the signal is odd.
always@(*) begin
	if(pool_shift) begin
		for(i=0;i<31;i=i+1) pool_w[i] = pool_r[i+1];
		pool_w[31] = 32'b0;	
	end else begin
		if(pool_cyc) begin
			if(!pool_cyc_cnt_r[0]) begin
				pool_w[31] = (pool_r[0] > pool_in) ? pool_r[0] : pool_in;
				for(i=0;i<31;i=i+1) pool_w[i] = pool_r[i+1];
			end else begin
				pool_w[31] = (pool_r[31] > pool_in) ? pool_r[31] : pool_in;
				for(i=0;i<31;i=i+1) pool_w[i] = pool_r[i];
			end
		end else begin
			for(i=0;i<32;i=i+1) pool_w[i] = pool_r[i];
		end
	end
end

always@(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		ar_addr_r <= 4'b0;
		ar_valid_r <= 1'b1;
		for(i=0;i<261;i=i+1)
			mem_r[i] <= 32'b0;
		for(i=0;i<16;i=i+1)
			buff_r[i] <= 32'b0;
		for(i=0;i<32;i=i+1)
			pool_r[i] <= 32'b0;
		for(i=0;i<9;i=i+1)
			prods_r[i] <= 32'b0;
		prods_cnt_r <= 13'b0;
		prods_valid_r <= 1'b0;
		mem_cnt_r <= 13'b0;
		buff_push_cnt_r <= 5'b0;
		buff_pop_cnt_r <= 5'b0;
		buff_pnt_r <= 5'b10000;
		pool_shift_cnt_r <= 5'b0;
		pool_cyc_cnt_r <= 5'b0;
		aw_addr0_r <= 5'b0;
		aw_addr1_r <= 5'b0;
		aw_valid_r <= 1'b1;
		w_switch_r <= 1'b0;
		mode_r <= 1'b0;
		aw_switch_r <= 1'b0;
	end else begin
		if(delayer) begin
			ar_addr_r <= ar_addr_w;
			ar_valid_r <= ar_valid_w;
			for(i=0;i<261;i=i+1)
				mem_r[i] <= mem_w[i];
			for(i=0;i<16;i=i+1)
				buff_r[i] <= buff_w[i];
			for(i=0;i<32;i=i+1)
				pool_r[i] <= pool_w[i];
			for(i=0;i<9;i=i+1)
				prods_r[i] <= prods_w[i];
			prods_cnt_r <= prods_cnt_w;
			prods_valid_r <= prods_valid_w;
			mem_cnt_r <= mem_cnt_w;
			buff_push_cnt_r <= buff_push_cnt_w;
			buff_pop_cnt_r <= buff_pop_cnt_w;
			buff_pnt_r <= buff_pnt_w;
			pool_shift_cnt_r <= pool_shift_cnt_w;
			pool_cyc_cnt_r <= pool_cyc_cnt_w;
			aw_addr0_r <= aw_addr0_w;
			aw_addr1_r <= aw_addr1_w;
			aw_valid_r <= aw_valid_w;
			w_switch_r <= w_switch_w;
			mode_r <= mode_w;
			aw_switch_r <= aw_switch_w;
		end
	end
end

endmodule