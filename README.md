# windows-scripts

Small Windows command-line and PowerShell utilities I keep reaching for.
Each script lives in its own folder with its own readme.

## Layout

```
windows-scripts/
├── README.md               # this file
├── install-apkm/           # ADB installer for .apkm bundles (PowerShell)
│   ├── install-apkm.ps1
│   └── readme.md
└── sleep-cmd/              # `sleep.cmd` -- a cmd.exe sleep command
    ├── sleep.cmd
    └── readme.md
```

## What's here

- **`install-apkm/`** -- `install-apkm.ps1` extracts an `.apkm` (the
  APKMirror / Aurora Store split-APK bundle format) and installs it on an
  ADB-connected device with `adb install-multiple`. Sideloads to Fire TV
  sticks, Android TVs, phones, etc.

- **`sleep-cmd/`** -- `sleep.cmd` is a one-liner that puts the PC to
  sleep from `cmd.exe`. There is no built-in for this, and pinning a tiny
  shortcut to the taskbar beats reaching for the Start menu.

## Conventions

- Each utility lives in its own folder, named after what it is.
- Subfolder `readme.md` documents that one utility's usage.
- PowerShell scripts use `[CmdletBinding()]` + named parameters so
  `Get-Help .\script.ps1` works.
- `cmd` scripts are kept as small and dependent-free as possible.

## License

MIT, do whatever you want with these.
