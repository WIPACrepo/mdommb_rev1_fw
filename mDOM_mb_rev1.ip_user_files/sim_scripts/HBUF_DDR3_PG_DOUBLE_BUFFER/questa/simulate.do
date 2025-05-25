onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib HBUF_DDR3_PG_DOUBLE_BUFFER_opt

do {wave.do}

view wave
view structure
view signals

do {HBUF_DDR3_PG_DOUBLE_BUFFER.udo}

run -all

quit -force
