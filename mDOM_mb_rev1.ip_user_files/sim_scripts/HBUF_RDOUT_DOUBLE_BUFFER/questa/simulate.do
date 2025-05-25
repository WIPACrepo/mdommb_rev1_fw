onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib HBUF_RDOUT_DOUBLE_BUFFER_opt

do {wave.do}

view wave
view structure
view signals

do {HBUF_RDOUT_DOUBLE_BUFFER.udo}

run -all

quit -force
