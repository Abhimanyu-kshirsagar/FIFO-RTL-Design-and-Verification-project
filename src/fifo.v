// fifo.v
// Parameterized synchronous FIFO (single clock domain)
// - Configurable DATA_WIDTH and DEPTH
// - full / empty flags, data_out and valid signal
// - simple binary pointer implementation with count

`timescale 1ns/1ps

module fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 16
)(
    input  wire                   clk,
    input  wire                   rst,       // synchronous active-high reset
    input  wire                   wr_en,     // write enable (attempt)
    input  wire                   rd_en,     // read enable (attempt)
    input  wire [DATA_WIDTH-1:0]  data_in,
    output reg  [DATA_WIDTH-1:0]  data_out,
    output wire                   full,
    output wire                   empty,
    output wire [$clog2(DEPTH):0] count      // number of stored elements (width = clog2(depth)+1)
);

    // local param for address width
    localparam ADDR_WIDTH = $clog2(DEPTH);

    // Memory
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers and count
    reg [ADDR_WIDTH-1:0] write_ptr;
    reg [ADDR_WIDTH-1:0] read_ptr;
    reg [ADDR_WIDTH:0]   cnt; // needs one extra bit to represent DEPTH

    // outputs
    assign full  = (cnt == DEPTH);
    assign empty = (cnt == 0);
    assign count = cnt;

    // Synchronous logic
    always @(posedge clk) begin
        if (rst) begin
            write_ptr <= {ADDR_WIDTH{1'b0}};
            read_ptr  <= {ADDR_WIDTH{1'b0}};
            cnt       <= { (ADDR_WIDTH+1){1'b0} };
            data_out  <= {DATA_WIDTH{1'b0}};
        end else begin
            // Write
            if (wr_en && !full) begin
                mem[write_ptr] <= data_in;
                write_ptr <= write_ptr + 1'b1;
            end

            // Read
            if (rd_en && !empty) begin
                data_out <= mem[read_ptr];
                read_ptr <= read_ptr + 1'b1;
            end

            // Update count (handle simultaneous r/w)
            case ({wr_en && !full, rd_en && !empty})
                2'b10: cnt <= cnt + 1; // only write
                2'b01: cnt <= cnt - 1; // only read
                2'b11: cnt <= cnt;     // both: count unchanged (store and fetch same cycle)
                default: cnt <= cnt;   // neither
            endcase
        end
    end

endmodule
