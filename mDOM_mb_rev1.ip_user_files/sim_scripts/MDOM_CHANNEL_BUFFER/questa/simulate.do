onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib MDOM_CHANNEL_BUFFER_opt

do {wave.do}

view wave
view structure
view signals

do {MDOM_CHANNEL_BUFFER.udo}

run -all

quit -force
