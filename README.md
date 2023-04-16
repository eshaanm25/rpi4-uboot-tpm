# TPM 2.0 in U-Boot on Raspberry Pi 4

This guide shows how to use the TPM 2.0 in the `U-Boot` bootloader prior to loading
the Linux kernel on Raspberry Pi 4. 

## Note

This guide was forked from [joholl/rpi4-uboot-tpm](https://github.com/joholl/rpi4-uboot-tpm) and uses follows similar steps. I have modified some steps to outline my process andd added additional files that were generated from my process.

## No Secure Boot on Raspberry Pi

Secure boot on the Raspberry Pi is not possible. That is because the first-stage
bootloader on the raspberry (`bootcode.bin` and `start.elf`) is closed source.
For secure boot, you need a so-called *Root of Trust* in the first-stage
bootloader, and we do not have that.

Actually, there is an [open-source first-stage
bootloader](https://github.com/christinaa/rpi-open-firmware) implemented mostly
via reverse-engineering. Unfortunately, this project has its limitations and is
currently on an indefinite hold.

## Pre-boot TPM

We want to be able to use the TPM prior to booting the Linux kernel. To do that,
we need to add a second-stage bootloader (`u-boot` in our case) with TPM
support.

The boot chain on the Raspberry Pi:

```
+-----------------+                                           +------------------------+
|   first-stage   |                                           |        Raspbian        |
|   bootloader    |------------------------------------------\|      Linux Kernel      |
|                 |------------------------------------------/|                        |
| (closed-source) |                                           | (built-in TPM support) |
+-----------------+                                           +------------------------+
```

What we want to achieve

```
+-----------------+        +-------------------------+        +------------------------+
|   first-stage   |        | second-stage bootloader |        |        Raspbian        |
|   bootloader    |-------\|          U-Boot         |-------\|      Linux Kernel      |
|                 |-------/|                         |-------/|                        |
| (closed-source) |        | (built-in TPM support)  |        | (built-in TPM support) |
+-----------------+        +-------------------------+        +------------------------+
```

## Preparing your Raspberry Pi

Get the headless Raspbian image.

```bash
wget -O raspian_latest.zip https://downloads.raspberrypi.org/raspbian_full_latest
unzip raspbian_latest.zip
```

Check the character device name of your SD card with `diskutil list` if needed. Plug
your SD card in, unmount its partition if necessary and flash the Raspbian image
onto the card:

```bash
sudo dd if=2020-02-13-raspbian-buster-full.img of=/dev/disk6 bs=4M status=progress conv=fsync
```

Done.

## Getting a TPM

There are various options. I chose the [Lets Trust TPM](https://buyzero.de/collections/andere-platinen/products/letstrust-hardware-tpm-trusted-platform-module?variant=33890452626). It's cheap and it's for Raspberry Pi. (Seriously, who doesn't hate jumper wires?)

## Getting a 64 Bit Kernel

We need to tell our bootloader to load the kernel in 64 bit mode.
We simply add the following line to `config.txt` on the boot partition.

```ini
arm_64bit=1
```
### Updating your 32 Bit Kernel to 64 Bit

Alternatively, you can instruct your Raspberry to perform a kernel update and reboot.

```
sudo rpi-update
sudo reboot
```

After the reboot, shut your Raspbian off and plug in the SD card to your PC.

### Building U-Boot

This is done with the help of Docker on Macs. Run `make build` in the home directory to generate the necessary files. For context on steps, see [joholl/rpi4-uboot-tpm](https://github.com/joholl/rpi4-uboot-tpm)
### Adding U-Boot to the Boot Chain

Now is the time to copy all U-Boot-related files onto the SD card.

```bash
cp boot-files/u-boot.bin /boot
cp boot-files/boot.scr.uimg /boot
cp boot-files/tpm-soft-spi.dtbo /boot/overlays
```

Additionally, we need to instruct the Raspberry's first-stage bootloader to use
our TPM device tree overlay and load U-Boot instead of the Linux kernel. Make
sure the following lines are in `config.txt`:

```ini
arm_64bit=1

dtparam=spi=on
dtoverlay=tpm-soft-spi

# if you want to use the serial console
enable_uart=1

kernel=u-boot.bin
```

Unmount the SD card and you are good to go!

# Testing

Connect your serial-to-USB converter to the Raspberry and open the terminal.
Boot your board and once the U-Boot bootloader starts, interrupt to enter
commands:

```
tpm2 init
tpm2 startup TPM2_SU_CLEAR
tpm2 get_capability 0x6 0x106 0x200 2
```

For an Infineon TPM you should get `0x534c4239` and `0x36373000` which is hex
for `SLB9670`. Congrats!

After calling `boot`, your Linux kernel should boot. Here, you can access your
TPM via `/dev/tpm0`.
