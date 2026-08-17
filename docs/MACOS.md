# Amigo on the Mac

Amigo is an iPad app, but on Apple Silicon Macs it installs and runs directly
from the Mac App Store as a "Designed for iPad" app. It is the same emulator
with the same features, running in a Mac window.

The one thing that differs is **where your Kickstart ROMs, disk images and hard
drives go** — on the Mac they don't live in a Files-app folder, and macOS hides
the location fairly well. This guide is mostly about that.

## Requirements

- An **Apple Silicon** Mac (M1 or newer). Intel Macs cannot run iPad apps.
- Install from the **Mac App Store**: search for *Amigo*, then open the
  **iPhone & iPad Apps** tab of the results.

## First launch

Amigo boots the bundled open-source AROS ROM immediately. With no ROMs or disks
added yet you'll land on the AROS **"Waiting for bootable media"** screen — that
is normal, not an error. It means the emulated Amiga is running and simply has
nothing to boot from yet.

The gear button in the top-right corner opens the menu. It fades out while you
work; click it to bring it back.

## Where to put your files

On iPad these folders are visible in the Files app under *On My iPad › Amigo*.
On the Mac the app is sandboxed and its Documents folder lives inside a
container whose name is a **random UUID that differs on every Mac**, so there is
no single path anyone can quote you.

**Launch Amigo at least once first** — the folders are created on first launch.

Then open the folder with this one-liner in Terminal:

```bash
open "$(dirname "$(grep -la de.amiga-imager.uae ~/Library/Containers/*/.com.apple.containermanagerd.metadata.plist | head -1)")/Data/Documents"
```

Inside you'll find the same folders as on the iPad:

| Folder | Put here |
|---|---|
| `Kickstarts` | Amiga Kickstart ROM files |
| `Floppies` | `.adf`, `.adz`, `.dms`, `.ipf`, and `.zip`/`.lha`/`.lzx`/`.7z` archives |
| `HardDrives` | `.hdf` hard-disk images (RDB or plain) |
| `CDs` | CD images: `.cue`+`.bin`, `.ccd`, `.mds`, `.nrg`, `.iso`, `.chd` |
| `Configuration` | saved setups (`.uae`) |
| `SaveStates` | save states |

Subfolders work — organise your library however you like, the pickers search
recursively.

### Make it convenient

Rather than running that command every time, link the folder into your home
directory once:

```bash
ln -s "$(dirname "$(grep -la de.amiga-imager.uae ~/Library/Containers/*/.com.apple.containermanagerd.metadata.plist | head -1)")/Data/Documents" ~/Amigo
```

Now you can drag files straight into `~/Amigo/Floppies`, `~/Amigo/Kickstarts`
and so on, and it shows up in the Finder sidebar if you drag it there.

Don't move or rename the container itself — the link points inside it, and macOS
manages that directory.

## Using it

Everything else works as on the iPad:

- **Gear menu** — insert disks, pick a Kickstart, mount hard drives and CDs,
  change the machine, save states, configurations.
- **Mouse** — the pointer works directly. The gear menu offers *1:1 Mouse*
  (pointer follows the cursor position) or the default relative/trackpad mode.
- **Keyboard** — your Mac keyboard drives the Amiga. The on-screen Amiga
  keyboard, numpad and function-key bar are in the gear menu for keys a Mac
  keyboard doesn't have.
- **Controllers** — pair a Bluetooth controller in System Settings, then assign
  it a port in the gear menu's Controller panel (CD32 pad mode and autofire
  included).
- **Fullscreen** — the green window button, or View → Enter Full Screen.

## Known quirks on the Mac

- **Both Shift keys currently register as the left Shift.** This affects games
  that use the two shifts as separate controls, most notably the pinball games
  (Pinball Dreams / Fantasies flippers). Workaround until it's fixed: the
  on-screen Amiga keyboard's two Shift keys *are* independent.
- **Right-click** is a right mouse button or a two-finger click on a trackpad.
- The window can be resized freely; the Amiga picture scales with it. The gear
  menu's *Picture: Fit* option keeps the original proportions instead of
  stretching.

## Troubleshooting

**"Waiting for bootable media"** — the emulator is running fine, it just has no
bootable disk. Add a Kickstart ROM and a disk image, or mount a hard drive.

**The container folder doesn't exist** — launch Amigo once, then try again.

**Files don't appear in the picker** — check the file extension is one of those
listed above. Files inside subfolders are found automatically; files with the
wrong extension are ignored.

**Where did my files go after reinstalling?** — deleting the app deletes its
container. Keep your ROM and disk library somewhere else and copy it in, or keep
the symlink above pointing at a folder you back up.

---

Amigo is free software (GPL-2). Source: <https://github.com/thomas-luebker/Amigo>
