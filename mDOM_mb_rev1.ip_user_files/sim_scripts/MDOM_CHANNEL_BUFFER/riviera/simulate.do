onbreak {quit -force}
onerror {quit -force}

asim -t 1ps +access +r +m+MDOM_CHANNEL_BUFFER -L xil_defaultlib -L xpm -L blk_mem_gen_v8_4_3 -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.MDOM_CHANNEL_BUFFER xil_defaultlib.glbl

do {wave.do}

view wave
view structure

do {MDOM_CHANNEL_BUFFER.udo}

run -all

endsim

quit -force
