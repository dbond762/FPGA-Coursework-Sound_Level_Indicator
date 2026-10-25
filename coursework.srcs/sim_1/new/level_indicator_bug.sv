// Копія level_indicator з НАВМИСНОЮ ПОМИЛКОЮ - тільки для перевірки тестбенчів.
// Не використовувати в синтезі. Під час симуляції має бути увімкнений
// або цей файл, або оригінал ip_repo/axi_level_indicator/level_indicator.sv.
//
// Помилка: модуль відліку abs_in зроблено регістром і записано неблокуючим
// присвоюванням у тому самому такті, що й зсув буфера. Тому в mem потрапляє
// СТАРЕ значення abs_in, тобто модуль попереднього відліку:
// буфер відстає від входу на один запис.

module level_indicator (
    input  wire        clk,
    input  wire        reset,
    input  wire [15:0] in_data,
    input  wire        in_valid,
    input  wire [3:0]  window,
    output reg  [15:0] peak,
    output reg  [3:0]  level
);

    initial $display("*** BUGGY level_indicator (registered abs_in) ***");

    reg [7:0][15:0] mem;
    reg [7:0][15:0] m;     // masked
    reg [3:0][15:0] cmp1;
    reg [1:0][15:0] cmp2;

    reg [15:0] abs_in;     // ПОМИЛКА: має бути комбінаційним (wire)

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            mem    <= '0;
            abs_in <= '0;
        end else if (in_valid) begin
            abs_in <= in_data[15] ? (~in_data + 16'd1) : in_data;
            mem    <= {mem[6:0], abs_in};   // сюди йде модуль ПОПЕРЕДНЬОГО відліку
        end
    end

    always_comb begin
        m[0] = mem[0];
        for (int i = 1; i < 8; i++) begin
            m[i] = (i < window) ? mem[i] : 0;
        end

        for (int i = 0; i < 4; i++) begin
            cmp1[i] = (m[i * 2] > m[i * 2 + 1]) ? m[i * 2] : m[i * 2 + 1];
        end

        for (int i = 0; i < 2; i++) begin
            cmp2[i] = (cmp1[i * 2] > cmp1[i * 2 + 1]) ? cmp1[i * 2] : cmp1[i * 2 + 1];
        end

        peak = (cmp2[0] > cmp2[1]) ? cmp2[0] : cmp2[1];

        level = (17'(peak) + 17'd4095) >> 12;
    end

endmodule
