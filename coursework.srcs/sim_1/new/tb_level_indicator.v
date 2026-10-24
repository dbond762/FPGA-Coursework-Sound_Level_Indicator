`timescale 1ns / 1ps

module tb_level_indicator();

    reg clk = 0;
    always #5 clk = ~clk;

    reg         reset;
    reg  [15:0] in_data;
    reg         in_valid;
    reg  [3:0]  window;
    wire [15:0] peak;
    wire [3:0]  level;

    level_indicator dut(
        .clk(clk), .reset(reset),
        .in_data(in_data), .in_valid(in_valid),
        .window(window),
        .peak(peak), .level(level)
    );

    // Один шаг теста: входной отсчёт -> ожидаемый пик -> ожидаемый уровень
    typedef struct {
        logic [15:0] data;
        logic [15:0] peak;
        logic [3:0]  level;
    } step_t;

    int errors = 0;

    task do_reset;
        begin
            in_valid = 0;
            reset = 1; @(posedge clk); #1;
            reset = 0; @(posedge clk); #1;
        end
    endtask

    // Проверка текущих выходов без записи
    task automatic check(
        input logic [15:0] exp_peak,
        input logic [3:0]  exp_level,
        input string       name
    );
        if (peak === exp_peak && level === exp_level) begin
            $display("PASS: %s: peak=%0d level=%0d", name, peak, level);
        end else begin
            $display("FAIL: %s: expected peak=%0d level=%0d, actual peak=%0d level=%0d",
                     name, exp_peak, exp_level, peak, level);
            errors++;
        end
    endtask

    // Одна запись отсчёта (импульс in_valid на один такт) и проверка
    task automatic entry(input step_t s, input string name);
        in_data  = s.data;
        in_valid = 1;
        @(posedge clk); #1;
        in_valid = 0;
        
        check(s.peak, s.level, name);
    endtask

    task automatic do_test(input string name, input logic [3:0] n, input step_t steps[]);
        do_reset();
        window = n;
        $display("%s (N=%0d)", name, n);
        
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

    task automatic check_min_window(input logic [3:0] n);
        step_t s[] = '{
            '{100, 100, 1},
            '{200, 200, 1}
        };
        do_test("check_min_window", n, s);
    endtask

    // Смена N без новых записей: старое большое значение выпадает и возвращается
    task automatic test_window_change;
        step_t s[] = '{
            '{30000, 30000, 8},
            '{   10, 30000, 8},
            '{   10, 30000, 8},
            '{   10, 30000, 8},
            '{   10, 30000, 8},
            '{   10, 30000, 8},
            '{   10, 30000, 8},
            '{   10, 30000, 8}
        };
        do_test("window change", 8, s);
        
        window = 3; #1;
        check(10, 1, "window change: N 8->3");
        window = 8; #1;
        check(30000, 8, "window change: N 3->8");
    endtask

    // Границы всех уровней (N=1, пик = последний отсчёт):
    // 4096*k -> уровень k, 4096*k+1 -> уровень k+1
    task automatic test_levels;
        step_t s[] = '{
            '{     0,     0, 0},
            '{     1,     1, 1},
            '{  4096,  4096, 1},
            '{  4097,  4097, 2},
            '{  8192,  8192, 2},
            '{  8193,  8193, 3},
            '{ 12288, 12288, 3},
            '{ 12289, 12289, 4},
            '{ 16384, 16384, 4},
            '{ 16385, 16385, 5},
            '{ 20480, 20480, 5},
            '{ 20481, 20481, 6},
            '{ 24576, 24576, 6},
            '{ 24577, 24577, 7},
            '{ 28672, 28672, 7},
            '{ 28673, 28673, 8},
            '{ 32767, 32767, 8},
            '{-32768, 32768, 8},
            '{    -1,     1, 1},
            '{ -4097,  4097, 2},
            '{-28673, 28673, 8}
        };
        do_test("levels", 1, s);
    endtask

    // Два одинаковых отсчёта подряд - это две записи, буфер сдвигается дважды
    task automatic test_repeat;
        step_t s[] = '{
            '{500, 500, 1},
            '{100, 500, 1},
            '{100, 100, 1}
        };
        do_test("repeat", 2, s);
    endtask

    // Без in_valid буфер не меняется, даже если in_data меняется и клок идёт
    task automatic test_no_write;
        step_t s[] = '{
            '{200, 200, 1}
        };
        do_test("no write", 1, s);
        in_data = 30000;
        repeat (3) @(posedge clk);
        #1;
        check(200, 1, "no write: in_valid=0");
    endtask

    initial begin
        in_valid = 0;
        in_data  = 0;
        window   = 1;

        test_1();
        test_2();
        test_3();
        check_min_window(0);
        check_min_window(1);
        test_window_change();
        test_levels();
        test_repeat();
        test_no_write();

        if (errors == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("%0d CHECK(S) FAILED", errors);
        end
        
        $finish;
    end

endmodule
