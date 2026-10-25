`timescale 1ns / 1ps

// Тестбенч AXI-обёртки: те же прогоны, что test_1..test_3 в tb_level_indicator,
// но через шину. После каждого отсчёта читаются регистры PEAK и LEVEL
// (и дополнительно сверяется внешний порт level).

module tb_axi_level_indicator();

    localparam logic [3:0] ADDR_IN    = 4'h0;
    localparam logic [3:0] ADDR_N     = 4'h4;
    localparam logic [3:0] ADDR_PEAK  = 4'h8;
    localparam logic [3:0] ADDR_LEVEL = 4'hC;

    reg clk = 0;
    always #5 clk = ~clk;

    reg aresetn;

    reg  [3:0]  awaddr;
    reg         awvalid;
    wire        awready;
    reg  [31:0] wdata;
    reg  [3:0]  wstrb;
    reg         wvalid;
    wire        wready;
    wire [1:0]  bresp;
    wire        bvalid;
    reg         bready;
    reg  [3:0]  araddr;
    reg         arvalid;
    wire        arready;
    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rvalid;
    reg         rready;

    wire [3:0]  level;

    axi_level_indicator dut (
        .level         (level),
        .s_axi_aclk    (clk),
        .s_axi_aresetn (aresetn),
        .s_axi_awaddr  (awaddr),
        .s_axi_awprot  (3'b000),
        .s_axi_awvalid (awvalid),
        .s_axi_awready (awready),
        .s_axi_wdata   (wdata),
        .s_axi_wstrb   (wstrb),
        .s_axi_wvalid  (wvalid),
        .s_axi_wready  (wready),
        .s_axi_bresp   (bresp),
        .s_axi_bvalid  (bvalid),
        .s_axi_bready  (bready),
        .s_axi_araddr  (araddr),
        .s_axi_arprot  (3'b000),
        .s_axi_arvalid (arvalid),
        .s_axi_arready (arready),
        .s_axi_rdata   (rdata),
        .s_axi_rresp   (rresp),
        .s_axi_rvalid  (rvalid),
        .s_axi_rready  (rready)
    );

    // Один шаг теста: входной отсчёт -> ожидаемый пик -> ожидаемый уровень
    typedef struct {
        logic [15:0] data;
        logic [15:0] peak;
        logic [3:0]  level;
    } step_t;

    int errors = 0;

    // ------------------------------------------------------------------
    // Все задачи начинаются и заканчиваются в момент "фронт + 1 нс",
    // когда выходы DUT уже стабильны.
    // ------------------------------------------------------------------

    task do_reset;
        begin
            awvalid = 0; wvalid = 0; bready = 0;
            arvalid = 0; rready = 0;
            awaddr  = 0; wdata  = 0; wstrb  = 0; araddr = 0;
            aresetn = 0;
            repeat (3) @(posedge clk);
            #1 aresetn = 1;
            @(posedge clk); #1;
        end
    endtask

    task automatic axi_write(input logic [3:0] addr, input logic [31:0] data);
        awaddr  = addr;  awvalid = 1;
        wdata   = data;  wstrb   = 4'hF; wvalid = 1;
        bready  = 1;

        // Каналы AW и W независимы - ждём каждый своего handshake
        fork
            begin
                while (!awready) begin @(posedge clk); #1; end
                @(posedge clk); #1;
                awvalid = 0;
            end
            begin
                while (!wready) begin @(posedge clk); #1; end
                @(posedge clk); #1;
                wvalid = 0;
            end
        join

        while (!bvalid) begin @(posedge clk); #1; end
        if (bresp !== 2'b00) begin
            $display("FAIL: write 0x%h: bresp=%b", addr, bresp);
            errors++;
        end
        @(posedge clk); #1;
        bready = 0;
    endtask

    task automatic axi_read(input logic [3:0] addr, output logic [31:0] data);
        araddr  = addr; arvalid = 1;
        rready  = 1;

        while (!arready) begin @(posedge clk); #1; end
        @(posedge clk); #1;
        arvalid = 0;

        while (!rvalid) begin @(posedge clk); #1; end
        data = rdata;
        if (rresp !== 2'b00) begin
            $display("FAIL: read 0x%h: rresp=%b", addr, rresp);
            errors++;
        end
        @(posedge clk); #1;
        rready = 0;
    endtask

    // Запись отсчёта в IN, затем чтение PEAK и LEVEL
    task automatic entry(input step_t s, input string name);
        logic [31:0] rd_peak, rd_level;

        axi_write(ADDR_IN, {{16{s.data[15]}}, s.data});
        axi_read(ADDR_PEAK,  rd_peak);
        axi_read(ADDR_LEVEL, rd_level);

        if (rd_peak === {16'h0, s.peak} && rd_level === {28'h0, s.level} && level === s.level) begin
            $display("PASS: %s: in=%0d PEAK=%0d LEVEL=%0d",
                     name, $signed(s.data), rd_peak, rd_level);
        end else begin
            $display("FAIL: %s: in=%0d expected PEAK=%0d LEVEL=%0d, actual PEAK=%0d LEVEL=%0d port level=%0d",
                     name, $signed(s.data), s.peak, s.level, rd_peak, rd_level, level);
            errors++;
        end
    endtask

    task automatic do_test(input string name, input logic [3:0] n, input step_t steps[]);
        logic [31:0] rd_n;

        do_reset();
        axi_write(ADDR_N, n);
        axi_read(ADDR_N, rd_n);
        $display("%s (N=%0d, read back N=%0d)", name, n, rd_n);
        if (rd_n !== {28'h0, n}) begin
            $display("FAIL: %s: N readback", name);
            errors++;
        end

        foreach (steps[i]) begin
            entry(steps[i], name);
        end
    endtask

    task automatic test_1;
        step_t s[] = '{
            '{ 100,  100, 1},
            '{-300,  300, 1},
            '{  50,  300, 1},
            '{  20,  300, 1},
            '{  10,  300, 1},
            '{   5,   50, 1}
        };
        do_test("test 1", 4, s);
    endtask

    task automatic test_2;
        step_t s[] = '{
            '{ 32767, 32767, 8},
            '{-32768, 32768, 8}
        };
        do_test("test 2", 1, s);
    endtask

    task automatic test_3;
        step_t s[] = '{
            '{     0,     0, 0},
            '{ 16384, 16384, 4},
            '{ 32767, 32767, 8},
            '{ 16384, 32767, 8},
            '{     0, 32767, 8},
            '{-16384, 16384, 4},
            '{-32768, 32768, 8}
        };
        do_test("test 3", 3, s);
    endtask

    initial begin
        test_1();
        test_2();
        test_3();

        if (errors == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("%0d CHECK(S) FAILED", errors);
        end
        
        $finish;
    end

    // Защита от зависания, если DUT не отвечает на handshake
    initial begin
        #100us;
        $display("FAIL: timeout");
        $finish;
    end

endmodule
