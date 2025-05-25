onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib MDOM_SECONDARY_BUFFER_opt

do {wave.do}

view wave
view structure
view signals

do {MDOM_SECONDARY_BUFFER.udo}

run -all

quit -force
