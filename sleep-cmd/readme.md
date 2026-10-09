# sleep.cmd

One-liner that puts the Windows PC to sleep from a `cmd.exe` shell.

```
rundll32.exe powrprof.dll,SetSuspendState 0,1,0
```

## Usage

```cmd
sleep.cmd
```

That's it -- no arguments, no flags. Pin it to Start, drop it on the taskbar,
or just run it from any terminal.

## Why a file instead of an alias

`cmd.exe` has no built-in `sleep` or `suspend` command. The classic
`rundll32 powrprof.dll` invocation directly invokes the SetSuspendState
API with `0,1,0` (Sleep, force-on, wake-without-password-prompt for
locked screens), which is exactly what the Start menu's "Sleep" tile does
under the hood.

## Notes

- Requires `rundll32.exe` and `powrprof.dll` (both standard on every
  modern Windows install).
- See `https://learn.microsoft.com/en-us/windows/win32/api/powerbase/nf-powerbase-setsuspendstate`
  for the flag meanings.
