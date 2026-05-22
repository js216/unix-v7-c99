LDSCRIPT = ../arch/arm.ld
DEVS = ../dev/pl011.o ../dev/virtio_blk.o
CONF_OBJS = ../conf/arm_qemu/conf.o
CONF_QEMU_ARGS = -machine virt -cpu cortex-a7 -nographic \
	-kernel ../unix -drive if=none,file=../root.img,format=raw,id=hd0 \
	-device virtio-blk-device,drive=hd0
