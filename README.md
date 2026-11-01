# EVGA Flow Control Sleep Fix

Fixes the **"CPUWB – Device not found"** error that EVGA Flow Control shows after Windows wakes from sleep, without rebooting.

## The problem

With an EVGA CLC AIO and EVGA Flow Control, waking the PC from sleep often brings up:

> CPUWB ! Device not found.

Flow Control then can't read or control the pump until the PC is fully rebooted. This has been reported on the EVGA forums and Reddit since 2017 without a working fix.

## What does NOT fix it

All of these were tested and did not help:

- Switching the pump/fan header from **PWM to DC (Voltage)** mode in BIOS (the most common suggestion online)
- Setting the fan header to Full Speed
- Unchecking "Allow the computer to turn off this device to save power" on USB hubs / HID devices
- Moving the AIO's USB cable to a different USB header or hub
- Closing and reopening Flow Control (and CLC Server)

## The cause

After sleep, the pump's USB controller (it shows in Device Manager as **Asetek USB Device** under *Universal Serial Bus controllers*) gets stuck. Windows still lists it as "working properly," so it never disappears, but Flow Control can't talk to it. Restarting the software doesn't help, because the device itself is the stuck part.

**Disabling and re-enabling the Asetek USB Device in Device Manager clears it instantly.** After that, Flow Control finds the pump again.

## The fix

This repo automates that. A scheduled task runs on every wake from sleep and:

1. Waits 5 seconds for USB to settle
2. Closes Flow Control (`CPUWB.exe`) and `CLCServer.exe`
3. Disables, then re-enables, the **Asetek USB Device**
4. Restarts Flow Control the same way Windows does at boot (through EVGA's own "EVGA Flow Control" task, which uses `/s` and loads your saved profile)

The whole thing takes about 20 seconds after waking. You may see the error popup briefly. Click OK or ignore it, and the script closes it either way. Nothing runs in the background between wakes, so there's no performance cost.

## Install

1. Download this repo (**Code → Download ZIP**) and extract it.
2. Open **PowerShell as Administrator** in the extracted folder.
3. Run:

```
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer checks for the Asetek device and Flow Control, copies the wake script to `C:\ProgramData\EVGAFlowControlSleepFix\`, and creates a scheduled task named **EVGA Flow Control Sleep Fix**.

To test it right away without sleeping:

```
schtasks /Run /TN "EVGA Flow Control Sleep Fix"
```

Flow Control should close and come back about 20 seconds later.

## Uninstall

In **PowerShell as Administrator**:

```
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

This removes the scheduled task and the script folder. Nothing else on your system is changed.

## Troubleshooting

- **Check the log:** `C:\ProgramData\EVGAFlowControlSleepFix\last-run.log` shows what happened on the last wake.
- **"Asetek USB Device not found":** open Device Manager → *Universal Serial Bus controllers* and check what your pump is called. If it has a different name, edit `$DeviceName` at the top of `RestartFlowControl.ps1` in the ProgramData folder.
- **Error still shows after waking:** USB may need longer to settle on your system. Raise `Start-Sleep -Seconds 5` at the top of the wake script to 8–10.
- **Flow Control doesn't show your profile as selected:** that's normal. Your profile's settings are still applied (check your pump/fan curve). It just doesn't show as selected in the menu.

## Tested on

- EVGA CLC 360
- EVGA Flow Control, default install path (`C:\Program Files (x86)\EVGA\Flow Control`)
- Windows 11, Gigabyte X870E Aorus Master

Other EVGA CLC models use Asetek pumps too and will likely work, but they haven't been verified. If it works (or doesn't) on yours, please open an issue so others know.

## Disclaimer

Provided as is, with no warranty. The script only restarts EVGA's own software and resets one USB device. It doesn't touch firmware, drivers or BIOS settings, and the pump keeps running normally throughout.
