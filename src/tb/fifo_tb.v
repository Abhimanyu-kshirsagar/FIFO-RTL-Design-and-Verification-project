// fifo_tb.v
// Self-checking testbench for fifo.v
`timescale 1ns/1ps

module fifo_tb;
    // Parameters for DUT
    parameter DATA_WIDTH = 8;
    parameter DEPTH      = 8;

    // Derived
    localparam ADDR_WIDTH = $clog2(DEPTH);

    // Signals
    reg clk;
    reg rst;
    reg wr_en;
    reg rd_en;
    reg [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;
    wire full;
    wire empty;
    wire [$clog2(DEPTH):0] count;

    // DUT
    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty),
        .count(count)
    );

    // Golden/reference model (simple circular buffer)
    reg [DATA_WIDTH-1:0] ref_mem [0:DEPTH-1];
    integer ref_head, ref_tail, ref_cnt;

    // Clock
    initial clk = 0;
    always #5 clk = ~clk; // 100 MHz -> 10ns period

    // Dump waves
    initial begin
        $dumpfile("sim/fifo_tb.vcd");
        $dumpvars(0, fifo_tb);
    end

    // Test sequence
    integer i;
    integer seed;
    initial begin
        // init
        seed = 42;
        wr_en = 0; rd_en = 0; data_in = 0;
        ref_head = 0; ref_tail = 0; ref_cnt = 0;

        // reset
        rst = 1;
        #20;
        rst = 0;
        #20;

        // Basic functional test: write then read
        $display("=== Basic write/read test ===");
        for (i = 0; i < DEPTH; i = i + 1) begin
            write_data(i);
            #10;
        end

        // FIFO should be full now
        if (!full) $display("ERROR: FIFO expected full but full==0");
        // try to write when full (should be ignored)
        write_data(8'hFF); #10;
        if (ref_cnt != DEPTH) $display("ERROR: Reference count mismatch after overflow attempt");

        // Now read all and check order
        for (i = 0; i < DEPTH; i = i + 1) begin
            read_and_check();
            #10;
        end
        if (!empty) $display("ERROR: FIFO expected empty but empty==0");

        // Underflow attempt: read when empty (should do nothing)
        read_and_check(); #10;

        // Randomized stress test: random writes/reads, compare with reference model
        $display("=== Randomized stress test ===");
        for (i = 0; i < 500; i = i + 1) begin
            // Randomize operations
            {wr_en, rd_en} = $urandom(seed) % 4; // gives 0..3 -> bits
            // Provide data when writing
            if (wr_en) data_in = $urandom(seed) & ((1<<DATA_WIDTH)-1);

            // apply for one cycle
            #10;

            // Update reference model according to allowed ops (respect full/empty)
            // But testbench must mimic DUT behaviour: if DUT didn't accept write because full, ref must not write
            // We decide write accepted if DUT not full at the beginning of cycle.
            // Use sampled signals at posedge boundary; ensure sampling consistent with DUT.
            // For this simple TB, check DUT flags to update reference.

            // Synchronize reference model to DUT: if write asserted and DUT not full then push.
            if (wr_en && !full) begin
                ref_mem[ref_tail] = data_in;
                ref_tail = (ref_tail + 1) % DEPTH;
                ref_cnt = ref_cnt + 1;
            end
            // If read asserted and DUT not empty then pop and compare
            if (rd_en && !empty) begin
                // expected data
                reg [DATA_WIDTH-1:0] expected;
                expected = ref_mem[ref_head];
                ref_head = (ref_head + 1) % DEPTH;
                ref_cnt = ref_cnt - 1;

                // Check DUT data out (note: DUT data_out updates on same cycle when rd_en && !empty)
                if (data_out !== expected) begin
                    $display("ERROR at cycle %0d: data_out mismatch. expected=%0h got=%0h", $time, expected, data_out);
                    $stop;
                end
            end

            // sanity checks: compare ref_cnt with DUT count
            if (ref_cnt !== count) begin
                $display("ERROR at time %0t: count mismatch. ref=%0d dut=%0d", $time, ref_cnt, count);
                $stop;
            end
        end

        $display("=== All tests passed ===");
        $finish;
    end

    // Task to write data (pulses wr_en for one cycle and updates reference)
    task write_data(input integer val);
        begin
            if (!full) begin
                data_in = val;
                wr_en = 1;
            end else begin
                // attempt write (should be blocked by DUT)
                data_in = val;
                wr_en = 1;
            end
            #10;
            wr_en = 0;

            // Update reference if DUT actually wrote (DUT's full sampled at time of write)
            // For the directed sequence above it will be non-full until full reached.
            if (!full) begin
                ref_mem[ref_tail] = val;
                ref_tail = (ref_tail + 1) % DEPTH;
                ref_cnt = ref_cnt + 1;
            end
        end
    endtask

    // Task to read one element and compare with reference
    task read_and_check();
        reg [DATA_WIDTH-1:0] expected;
        begin
            if (!empty) begin
                rd_en = 1;
                #10;
                rd_en = 0;
                // expected value is at ref_head
                expected = ref_mem[ref_head];
                // check DUT output
                if (data_out !== expected) begin
                    $display("ERROR: Read mismatch. expected=%0h got=%0h at time %0t", expected, data_out, $time);
                    $stop;
                end
                // update reference
                ref_head = (ref_head + 1) % DEPTH;
                ref_cnt = ref_cnt - 1;
            end else begin
                // read when empty (should not change anything)
                rd_en = 1; #10; rd_en = 0;
            end
        end
    endtask

endmodule
