`timescale 1ns / 1ps

// AXI4-Lite обёртка для level_indicator.
//
// Регистры (смещение от базового адреса):
//   0x00 IN    W   [15:0] знаковый отсчёт; каждая запись = один шаг
//   0x04 N     RW  [3:0]  размер окна 1..8; запись вне диапазона игнорируется
//   0x08 PEAK  R   [15:0] текущий пик (беззнаковый)
//   0x0C LEVEL R   [3:0]  текущий уровень 0..8
//
// Чтение IN возвращает 0. Запись в PEAK/LEVEL игнорируется.
// Все ответы - OKAY.

module axi_level_indicator (
    // Наружу, на светодиоды
    output wire [3:0] level,

    // AXI4-Lite slave
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,

    input  wire [3:0]  s_axi_awaddr,
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,

    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,

    output wire [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [3:0]  s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,

    output reg  [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready
);

    localparam int C_S_AXI_DATA_WIDTH = 32;

    localparam logic [1:0] REG_IN    = 2'd0;   // 0x00
    localparam logic [1:0] REG_N     = 2'd1;   // 0x04
    localparam logic [1:0] REG_PEAK  = 2'd2;   // 0x08
    localparam logic [1:0] REG_LEVEL = 2'd3;   // 0x0C

    localparam logic [3:0] N_RESET   = 4'd1;

    wire clk   = s_axi_aclk;
    wire reset = ~s_axi_aresetn;

    // ------------------------------------------------------------------
    // Запись. Канал адреса (AW) и данных (W) принимаются независимо,
    // в любом порядке; когда есть оба и канал ответа свободен - запись.
    // ------------------------------------------------------------------
    logic        aw_full;
    logic [1:0]  aw_reg;
    logic        w_full;
    logic [31:0] w_data;
    logic [3:0]  w_strb;

    assign s_axi_awready = ~aw_full;
    assign s_axi_wready  = ~w_full;
    assign s_axi_bresp   = 2'b00;   // OKAY

    wire do_write = aw_full && w_full && !s_axi_bvalid;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            aw_full      <= 1'b0;
            aw_reg       <= '0;
            w_full       <= 1'b0;
            w_data       <= '0;
            w_strb       <= '0;
            s_axi_bvalid <= 1'b0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                aw_full <= 1'b1;
                aw_reg  <= s_axi_awaddr[3:2];
            end

            if (s_axi_wvalid && s_axi_wready) begin
                w_full <= 1'b1;
                w_data <= s_axi_wdata;
                w_strb <= s_axi_wstrb;
            end

            if (do_write) begin
                aw_full      <= 1'b0;
                w_full       <= 1'b0;
                s_axi_bvalid <= 1'b1;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // Регистр N
    logic [3:0] n_reg;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            n_reg <= N_RESET;
        end else if (do_write && aw_reg == REG_N && w_strb[0]) begin
            if (w_data[3:0] >= 4'd1 && w_data[3:0] <= 4'd8 && w_data[31:4] == '0)
                n_reg <= w_data[3:0];
        end
    end

    // ------------------------------------------------------------------
    // Ядро. in_valid - импульс на один такт в момент записи в IN.
    // ------------------------------------------------------------------
    wire        core_in_valid = do_write && (aw_reg == REG_IN);
    wire [15:0] core_peak;
    wire [3:0]  core_level;

    level_indicator core (
        .clk      (clk),
        .reset    (reset),
        .in_data  (w_data[15:0]),
        .in_valid (core_in_valid),
        .window   (n_reg),
        .peak     (core_peak),
        .level    (core_level)
    );

    assign level = core_level;

    // ------------------------------------------------------------------
    // Чтение
    // ------------------------------------------------------------------
    assign s_axi_arready = ~s_axi_rvalid;
    assign s_axi_rresp   = 2'b00;   // OKAY

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rdata  <= '0;
        end else if (s_axi_arvalid && s_axi_arready) begin
            s_axi_rvalid <= 1'b1;
            case (s_axi_araddr[3:2])
                REG_N:     s_axi_rdata <= {{(C_S_AXI_DATA_WIDTH-4){1'b0}},  n_reg};
                REG_PEAK:  s_axi_rdata <= {{(C_S_AXI_DATA_WIDTH-16){1'b0}}, core_peak};
                REG_LEVEL: s_axi_rdata <= {{(C_S_AXI_DATA_WIDTH-4){1'b0}},  core_level};
                default:   s_axi_rdata <= '0;   // IN - только запись
            endcase
        end else if (s_axi_rvalid && s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
        end
    end

endmodule
