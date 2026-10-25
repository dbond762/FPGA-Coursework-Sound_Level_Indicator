`timescale 1ns / 1ps

// Системний тестбенч для запуску всієї системи (MicroBlaze + програма + IP).
// Програма має бути зібрана з SIMULATION (без usleep і xil_printf).

module tb_design();

    // PYNQ-Z2: 125 МГц, одиночний клок
    reg sys_clk = 0;
    always #4 sys_clk = ~sys_clk;

    // BTN0: активний рівень 1
    reg reset_rtl_0 = 1;

    wire [3:0] level;

    design_1_wrapper dut (
        .sys_clk     (sys_clk),
        .reset_rtl_0 (reset_rtl_0),
        .level       (level)
    );

    initial begin
        #200;
        reset_rtl_0 = 0;

        // Час на запуск MicroBlaze і виконання програми
        #200us;
        $finish;
    end

endmodule
