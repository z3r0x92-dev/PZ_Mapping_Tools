# Windows release verification

`Verify-PZToolsRelease.ps1` checks an extracted Windows package without
changing any editor source code or application UI.

It verifies:

- the three editor executables;
- required configuration catalogues;
- recommended portable data and documentation directories;
- native DLL imports when Visual Studio `dumpbin.exe` is available;
- Qt's required Windows platform plugin; and
- optional SHA-256 hashes for immutable packaged files.

The hash manifest intentionally excludes `settings`, because that directory
contains writable preferences and live log files created after the tools run.
An unreadable file elsewhere is reported as a warning instead of terminating
the complete verification run.

The verifier automatically handles archives that contain one extra top-level
folder. Its report is written into the detected package root as
`PZTools-release-verification.txt` unless `-ReportPath` is supplied.

## Quick start

Run from a Visual Studio Developer Command Prompt for the complete DLL scan:

```bat
tools\release\Verify-PZToolsRelease.cmd "C:\PZ_Mapping_Tools\release\PZTools-Modernized-v1.0.0-Restored" -WriteManifest
```

The process exits with:

- `0` when all required checks pass;
- `1` when the release is incomplete; or
- `2` when the supplied package path cannot be inspected.

Warnings identify recommended files or checks that could not be confirmed.
Failures identify release-blocking problems. Do not publish a package while
the verifier reports failures.

Never obtain a missing DLL from a generic DLL-download website. Rebuild or
copy the matching dependency from the same PZTools compiler output, rerun
`windeployqt`, and verify the package again.
