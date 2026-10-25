module level_indicator (
    input  wire        clk,
    input  wire        reset,
    input  wire [15:0] in_data,
    input  wire        in_valid,
    input  wire [3:0]  window,
    output reg  [15:0] peak,
    output reg  [3:0]  level
);
    
    reg [7:0][15:0] mem;
    reg [7:0][15:0] m;     // masked
    reg [3:0][15:0] cmp1;
    reg [1:0][15:0] cmp2;
    reg [15:0]      peak_next;   // комбінаційний максимум вікна
    reg [7:0]       win_mask;    // win_mask[i] = 1, якщо mem[i] у вікні
    
    wire [15:0] abs_in = in_data[15] ? (~in_data + 16'd1) : in_data;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            mem <= '0;
        end else if (in_valid) begin
            mem <= {mem[6:0], abs_in};
        end
    end

    // Маска вікна як регістр: порівняння i < window виконується тут,
    // а не на початку довгого шляху до регістра піку.
    // mem[0] завжди у вікні, тому N = 0 поводиться як N = 1.
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            win_mask <= 8'b0000_0001;
        end else begin
            for (int i = 0; i < 8; i++)
                win_mask[i] <= (i == 0) || (i < window);
        end
    end

    // Регістр піку: розрізає довгий комбінаційний шлях
    // (маска -> дерево порівнянь -> рівень -> мультиплексор читання AXI).
    // Пік оновлюється через один такт після запису відліку або зміни N.
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            peak <= '0;
        end else begin
            peak <= peak_next;
        end
    end
    
    always_comb begin
        for (int i = 0; i < 8; i++) begin
            m[i] = win_mask[i] ? mem[i] : '0;
        end
        
        for (int i = 0; i < 4; i++) begin
            cmp1[i] = (m[i * 2] > m[i * 2 + 1]) ? m[i * 2] : m[i * 2 + 1];
        end
        
        for ( int i = 0; i < 2; i++ ) begin
            cmp2[i] = (cmp1[i * 2] > cmp1[i * 2 + 1]) ? cmp1[i * 2] : cmp1[i * 2 + 1];
        end
        
        peak_next = (cmp2[0] > cmp2[1]) ? cmp2[0] : cmp2[1];
    end

    // level = ceil(peak / 4096) = peak[15:12] + (молодші 12 біт не нуль).
    // Те саме, що (peak + 4095) >> 12, але 4-бітний інкремент замість 17-бітного суматора.
    // peak <= 0x8000, тому результат 0..8 вміщується в 4 біти.
    always_comb begin
        level = peak[15:12] + {3'b000, |peak[11:0]};
    end

endmodule