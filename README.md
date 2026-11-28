# iOS27StatusBar 1.4.0 — semantic reconstruction build

This branch packages a readable, static semantic reconstruction of the supplied iOS27StatusBar binary as a **single arm64e, native Roothide-scheme** Theos tweak. It is not the author's original source and has not been tested on an iOS device. A successful GitHub Actions build proves compilation/package creation only, not runtime equivalence or compatibility.

## Source and attribution

- Four Objective-C++ modules: `Sources/I27REBattery.mm`, `I27REDrawing.mm`, `I27RERuntime.mm`, and `I27REHooks.mm`.
- Public reconstruction interfaces: `Headers/`.
- Original injection filter for SpringBoard and UIKit: `layout/Library/MobileSubstrate/DynamicLibraries/iOS27StatusBar.plist`.
- Static reverse-engineering notes and validation boundaries: `docs/`.
- Source reconstruction was based on the user's supplied deb (SHA-256 `c4941a3a6c34854420fa7c7bebcdad2768ede4c7392a052ca15bb5618fedddb7`). No original binary is included or executed here.
- Original package credits retained from its control metadata: 半生年华, yaowell, Benja Guo. The package's source description credits Benja Guo for signal/Wi-Fi artwork. No claim of authorship or original source recovery is made.

## Build

The workflow pins Roothide Theos and the theos/sdks repository to commit hashes, selects iPhoneOS 16.5 SDK, builds only the `roothide` scheme with `ARCHS=arm64e`, and uploads the `.deb` as a 30-day GitHub Actions artifact. It does not publish a GitHub Release, install the tweak, restart SpringBoard, or connect to a device.

Local command on a compatible macOS runner:

```sh
THEOS=/path/to/roothide-theos sh build.sh roothide
```

The package verifier checks package metadata, the injected filter, and that the packaged dylib is a thin Mach-O arm64e slice. It does not validate code behavior on-device.

## Important limits

The local syntax and object-generation checks passed, but no full Theos link/package had been completed when this project was prepared. The cloud build is the first end-to-end Theos packaging attempt for this reconstruction. No original dylib is linked into the output. Do not treat the resulting package as a byte-for-byte rebuild or a verified drop-in replacement; install and device testing remain separate and are not performed by CI.
