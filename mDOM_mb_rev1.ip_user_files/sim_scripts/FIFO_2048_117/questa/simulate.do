onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib FIFO_2048_117_opt

do {wave.do}

view wave
view structure
view signals

do {FIFO_2048_117.udo}

run -all

quit -force
