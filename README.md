# Satellite

Satellite allows you to use any other computer as an additional display to your
Mac computer. It is built by combining several open source components.

 - **[IOProxyVideoFamily][ioproxyvideofamily]** Provides two kernel
   extensions that implement the virtual video card and framebuffer.

 - **vncserver** Command line utility to start a VNC server to view the virtual
   monitor with your favorite VNC client. It is built using
   [libvncserver][libvncserver].

[ioproxyvideofamily]: https://code.google.com/p/ioproxyvideofamily/
[libvncserver]: http://libvnc.github.io/

## Installation

<span style="color:red; font-weight:bold;">
Make sure you have sshd active and a spare computer nearby in case anything goes
wrong!
</span>

Clone the repo and run `./install.sh`. The script builds the binaries, installs
the kexts and installs `vncserver` in `/usr/bin`.

Now reboot. It might be that your Mac decided to use the newly attached monitor
as your main screen. In that case your login screen won't show up, so just type
your password when the gray area appears.

Open the system preferences and arrange your displays.

Open a terminal and start `vncserver`. Select the display you want to stream.

Open your favorite VNC client on the other computer and connect to your Mac.
Using an ethernet cable is recommended.

## Deactivate or Uninstall

To deactivate the extra monitor remove `IOProxyFramebuffer.kext` and
`IOProxyVideoCard.kext` from `/System/Library/Extensions` and reboot.

To completely uninstall every component run `./uninstall.sh` in your cloned
repository.

## Warning
I do not have any experience building kernel extensions. I just took the code,
compiled it and wrote a naive VNC implementation. If anything goes wrong I
probably won't be able to help you!

## Known problems

 - When the Mac display goes to sleep, the virtual mintor prevents the Mac from
   firing up again. You'll have to use your on/off button to force reboot your
   Mac. (See *Console* for detailed error messages)

## Todo
 
 - Solve known problems
 - Dynamic kernel extension activation without reboot
 - Alternative to slow VNC



