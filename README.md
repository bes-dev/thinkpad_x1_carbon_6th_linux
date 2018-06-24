* Linux configuration guide for Thinkpad x1 Carbon 6th Gen (2018)

This guide workable for Lenovo ThinkPad Ultrabook X1 Carbon Gen6 (20KH006HRT) and Ubuntu 18.04.
If you follow this guide, no one is responsible for any damage to your hardware or any other kind of harming your machine.

** Install Ubuntu 18.04

If touchpad andr/or trackpoint don't work on Ubuntu installer, add 'psmouse.synaptics_intertouch=1' to loader.

** Install latest version of Linux Kernel

Firstly, after instalation, update Linux Kernel (because in kernels 4.17.x power management has improved) using UKUU:
```
$ sudo add-apt-repository ppa:teejee2008/ppa
$ sudo apt-get update
$ sudo apt-get install ukuu
$ sudo ukuu --check
$ sudo ukuu --install-latest
```

** Touchpad & Trackpoint

1. Edit the /etc/modprobe.d/blacklist.conf file and comment out following line:

```
# blacklist i2c_i801
```

2. Edit the /etc/default/grub file and change line:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
```
to
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash psmouse.synaptics_intertouch=1"
```

3. update grub:
```
$ sudo update-grub
```

4. install xserver-synaptics:

```
$ sudo apt-get install xserver-xorg-input-synaptics
```

5. Copy wakeup-control script from this repo to /lib/systemd/system-sleep/ for wakeup touchpad/trackpoint after sleep.

** Deep sleep

1. Reboot, enter your BIOS/UEFI. Go to Config - Thunderbolt (TM) 3 - set Thunerbolt BIOS Assist Mode to Enabled. It has also been reported that Security - Secure Boot must be disabled.

2. Install iasl (Intel's compiler/decompiler for ACPI machine language) and cpio from your distribution.

3. Get a dump of your ACPI DSDT table.
```
$ cat /sys/firmware/acpi/tables/DSDT > dsdt.aml
```

4. Decompile the dump, which will generate a .dsl source based on the .aml ACPI machine language dump.
```
$ iasl -d dsdt.aml
```

5. Apply X1Y3_S3_DSDT.patch it against dsdt.dsl:
```
$ patch --verbose < X1C6_S3_DSDT.patch
```
Note: Hunk 6 may fail due to different specified memory regions. In this case, simply edit the (almost fully patched) dsdt.dsl file, search for and entirely delete the two lines reading solely the word "One". You can look at hunk 6 in the patch file to see how the lines above and below look like if you're unsure.

Plan B: If this does not work (patch is rejected): It has been the case, that certain UEFI settings may lead to different DSDT images. This means that it may be possible that the above patch doesn't work at all with your decompiled DSL. If that is the case, don't worry: Go through the .patch file in your editor, and change your dsdt.dsl by hand. This means locating the lines which are removed in the patch and removing them in your dsl. The patch contains only one section at the end which adds a few lines - these are important and make the sleep magic happen.

6. Make sure that the hex number at the end of the first non-commented line is incremented by one (reading DefinitionBlock, should be around line 21). E.g., if it was 0x00000000 change it to 0x00000001. Otherwise, the kernel won't inject the new DSDT table.

7. Recompile your patched version of the .dsl source.
```
$ iasl -ve -tc dsdt.dsl
```

8. There shouldn't be any errors. When recompilation was successful, iasl will have built a new binary .aml file including the S3 patch. Now we have to create a CPIO archive with the correct structure, which GRUB can load on boot (much like initrd is loaded). We name the final image acpi_override and copy it into /boot/.

```
$ mkdir -p kernel/firmware/acpi
$ cp dsdt.aml kernel/firmware/acpi
$ find kernel | cpio -H newc --create > acpi_override
$ cp acpi_override /boot
```

9. We yet have to tell GRUB to load our new DSDT table on boot in its configuration file, usually located in /boot/grub/grub.cfg or something similar. Look out for the GRUB menu entry you're usually booting, and simply add our new image to the initrd line. It should look somewhat like that (if your initrd line contains other elements, leave them as they are and simply add the new ACPI override):
```
initrd   /acpi_override /initramfs-linux.img
```
Note: You will need to do this again when your distribution updates the kernel and re-writes the GRUB configuration. I'm looking for a more automated approach, but was too lazy to do it so far.

10. Moreover, GRUB needs to boot the kernel with a parameter setting the deep sleep state as default. The best place to do this is /etc/default/grub, since that file is not going to be overwritten when the GRUB config becomes regenerated. Simply add mem_sleep_default=deep to the GRUB_CMDLINE_LINUX_DEFAULT configuration option. It should look somewhat like that:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet mem_sleep_default=deep"
```

11. Reboot

If everything worked, you shouldn't see any boot errors and the kernel will confirm that S3 is working. The output of the following commands should look the same on your machine:

```
$ dmesg | grep ACPI | grep supports"
  [    0.213668] ACPI: (supports S0 S3 S4 S5)
$ cat /sys/power/mem_sleep
  s2idle [deep]
```

In most setups, simply closing the lid will probably trigger deep sleep. If you're using a systemd-based distribution (most of which are), you can also verify if it works on the command line:
```
$ systemctl suspend -i
```
Once again, many thanks to Ranguvar for the great collaboration on the Arch forums, and to fiji-flo for managing to hack the first fully working patch. Also, to whomever wrote the article on DSDT patching in the glorious Arch Wiki. And the entire Arch community in general, you're wonderful.

** low cTDP and trip temperature in Linux

This problem is related to thermal throttling on Linux, that is set much below the Windows values. This will cause your laptop to run much slower than it could under heavy stress.

Before you attempt to apply this solution, please make sure that the problem still exists when you read it. To do so, open a Linux terminal and run following commands:
```
$ sudo apt-get install msr-tools
$ sudo rdmsr -f 29:24 -d 0x1a2
```
If you see 3 as a result value (or 15 when running on battery), you don’t have to do anything. Otherwise:
1. Disable Secure Boot in the BIOS (won’t work otherwise)
2. Run this command:
```
sudo apt install git virtualenv build-essential python3-dev \
  libdbus-glib-1-dev libgirepository1.0-dev libcairo2-dev
```
3. Install lenovo-throttling-fix:
```
$ cd lenovo-throttling-fix/
$ sudo ./install.sh
```
Check again, that the result from running the rdmsr command is 3

Personally, I use a bit lower temperature levels to preserve battery life in favor of performance. If you want to change the default values, you need to edit the /etc/lenovo_fix file and set the Trip_Temp_C for both battery and AC the way you want:
```
[BATTERY]
# Other options here...
PL2_Tdp_W: 40
Trip_Temp_C: 75

[AC]
# Other options here...
PL1_Tdp_W: 34
PL2_Tdp_W: 40
Trip_Temp_C: 90
```

** CPU undervolting

The amazing Lenovo Throttling fix script supports also the undervolting. To enable it, please edit the /etc/lenovo_fix.conf again and update the [UNDERVOLT] section. In my case, this settings proven to be stable:

```
[UNDERVOLT]
# CPU core voltage offset (mV)
CORE: -110
# Integrated GPU voltage offset (mV)
GPU: -90
# CPU cache voltage offset (mV)
CACHE: -110
# System Agent voltage offset (mV)
UNCORE: -90
# Analog I/O voltage offset (mV)
ANALOGIO: 0
```

** Battery charging thresholds

There are a lot of theories and information about ThinkPad charging thresholds. Some theories say thresholds are needed to keep the battery healthy, some think they are useless and the battery will work the same just as it is. In this article I will try not to settle that argument. 🙂 Instead I try to tell how and why I use them, and then proceed to show how they can be changed in different versions of Windows, should you still want to change these thresholds.

I always stick with following settings for my laptops (and somehow I feel that it works):

- Start threshold: 45%
- Stop threshold: 95%

This means that the charging will start only if the battery level goes down below 45% and will stop at 95%. This prevents battery from being charged too often and from being charged beyond a recommended level.

To achieve this for Linux based machines you need to install some packages by running:

```
$ sudo apt-get install tlp tlp-rdw acpi-call-dkms tp-smapi-dkms acpi-call-dkms
```

After that just edit the /etc/default/tlp file and edit following values:
```
# Uncomment both of them if commented out
START_CHARGE_THRESH_BAT0=45
STOP_CHARGE_THRESH_BAT0=95
```

Reboot, run:
```
sudo tlp-stat | grep tpacpi-bat
```

and check if the values are as you expect:
```
tpacpi-bat.BAT0.startThreshold          = 45 [%]
tpacpi-bat.BAT0.stopThreshold           = 95 [%]
```

You can change these thresholds anytime, and apply changes using command:
```
$ sudo tlp start
```

Note, that if you need to have your laptop fully charged, you can achieve that by running following command while connected to AC:
```
$ tlp fullcharge
```
