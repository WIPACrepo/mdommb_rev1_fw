onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib OVERFLOW_FIFO_opt

do {wave.do}

view wave
view structure
view signals

do {OVERFLOW_FIFO.udo}

run -all

quit -force
