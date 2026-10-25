## Системний клок PL: 125 МГц, одиночний (не диференційний).
set_property -dict { PACKAGE_PIN H16  IOSTANDARD LVCMOS33 } [get_ports sys_clk]

## Скидання: кнопка BTN0 (натиснута = 1, активний рівень 1)
set_property -dict { PACKAGE_PIN D19  IOSTANDARD LVCMOS33 } [get_ports reset_rtl_0]

## Рівень на світлодіоди LD0..LD3 (двійковий код 0..8)
set_property -dict { PACKAGE_PIN R14  IOSTANDARD LVCMOS33 } [get_ports {level[0]}]
set_property -dict { PACKAGE_PIN P14  IOSTANDARD LVCMOS33 } [get_ports {level[1]}]
set_property -dict { PACKAGE_PIN N16  IOSTANDARD LVCMOS33 } [get_ports {level[2]}]
set_property -dict { PACKAGE_PIN M14  IOSTANDARD LVCMOS33 } [get_ports {level[3]}]
