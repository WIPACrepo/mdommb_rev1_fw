onbreak {quit -force}
onerror {quit -force}

asim -t 1ps +access +r +m+FIFO_2048_117 -L xil_defaultlib -L xpm -L fifo_generator_v13_2_4 -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.FIFO_2048_117 xil_defaultlib.glbl

do {wave.do}

view wave
view structure

do {FIFO_2048_117.udo}

run -all

endsim

quit -force
