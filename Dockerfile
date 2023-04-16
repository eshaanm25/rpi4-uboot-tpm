FROM --platform=linux/amd64 ubuntu:22.04 AS stage1

RUN apt-get update

# Install Dependencies
RUN apt-get install -y git make libssl-dev gcc-aarch64-linux-gnu gcc bison flex libncurses-dev device-tree-compiler bc

# Clone u-boot
WORKDIR /proj
RUN git clone https://gitlab.denx.de/u-boot/u-boot.git --depth 1
WORKDIR /proj/u-boot

# Build Config File
RUN make -j5 CROSS_COMPILE=aarch64-linux-gnu- rpi_4_defconfig
COPY .config .config

# Build U-Boot
RUN make -j$(nproc) CROSS_COMPILE=aarch64-linux-gnu- all

# Build boot files
COPY boot.scr .
COPY tpm-soft-spi.dts .
RUN ./tools/mkimage -A arm64 -T script -C none -n "Boot script" -d boot.scr boot.scr.uimg
RUN dtc -O dtb -b 0 -@ tpm-soft-spi.dts -o tpm-soft-spi.dtbo

FROM scratch 

COPY --from=stage1 /proj/u-boot/boot.scr.uimg .
COPY --from=stage1 /proj/u-boot/tpm-soft-spi.dtbo .
COPY --from=stage1 /proj/u-boot/u-boot.bin .