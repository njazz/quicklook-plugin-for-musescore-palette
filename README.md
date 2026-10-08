# quicklook-plugin-for-musescore-palette

**Unofficial Quick Look plugin for MuseScore palette files (`.mpal`), for macOS.**

Select an `.mpal` file in Finder and press Space. The preview shows the palette name, its cell count and
grid size, and one card per cell with the symbol, the cell name and the element type.

It ships as a small app, **MPAL File Preview**, that carries the Quick Look extension. It's a Swift
package for macOS 12 or later, with no dependencies. It complements the built-in score previews (`.mscz`)
in recent MuseScore Studio releases (for example 4.7.5), which don't cover palettes.

> Not affiliated with or endorsed by MuseScore or Muse Group.
> MuseScore is a trademark of its respective owner. macOS and Finder are trademarks of Apple Inc.

## Install

### Option A: download the app

1. Download `MpalFilePreview.zip` from [Releases](../../releases) and unzip it.
2. Move `MpalFilePreview.app` to `/Applications` and open it once. Its window shows whether the Quick Look
   extension is registered. You can then quit the app, but keep it installed: the extension lives inside it.
3. The app isn't notarized, so macOS blocks the first launch. Go to **System Settings › Privacy & Security**
   and click **Open Anyway**, or run:
   `xattr -dr com.apple.quarantine /Applications/MpalFilePreview.app`

To remove it, move the app to the Trash.

### Option B: build from source

You need the Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/<you>/quicklook-plugin-for-musescore-palette.git
cd quicklook-plugin-for-musescore-palette
./install_mac.sh                 # build, sign (ad-hoc), install to ~/Applications, register
qlmanage -p Examples/Percussion_Sticking.mpal
./install_mac.sh --uninstall
```

## Build the app for distribution

```sh
./build_app.sh                   # -> dist/MpalFilePreview.zip (native arch)
UNIVERSAL=1 ./build_app.sh       # arm64 + x86_64, needs full Xcode
```

The GitHub workflow (`.github/workflows/build.yml`) builds the universal app on every push. When you push
a tag like `v1.0.0`, it attaches `MpalFilePreview.zip` to that release.

| Option                                  | Default                   | Purpose                                            |
| --------------------------------------- | ------------------------- | -------------------------------------------------- |
| `DEST=/Applications`                    | `~/Applications`          | Install location (`install_mac.sh` only)           |
| `SIGN_ID="…"`                           | `-` (ad-hoc)              | Signing identity (`security find-identity -v -p codesigning`) |
| `BUNDLE_ID=com.yourdomain.mpal-preview` | `local.mpal-file-preview` | App bundle ID; the extension gets `<id>.quicklook` |
| `VERSION=1.0.0`                         | `1.0`                     | Version shown in Finder                            |
| `UNIVERSAL=1`                           | off                       | Build for both Apple silicon and Intel             |

With a paid Apple Developer account you can sign with `SIGN_ID="Developer ID Application: …"`, which turns on
hardened runtime. If you also notarize the zip (`xcrun notarytool submit dist/MpalFilePreview.zip …`), the
downloaded app opens without the Gatekeeper warning.

## Develop without installing

```sh
swift run mpal2html Examples/Percussion_Sticking.mpal > /tmp/p.html && open /tmp/p.html
```

## Layout

```
Package.swift
Sources/
  MpalCore/Mpal.swift                             zip reader + palette XML → HTML (all the real logic)
  MpalFilePreviewExtension/PreviewProvider.swift  Quick Look extension (QLPreviewProvider → HTML)
  MpalFilePreviewExtension/main.swift             calls NSExtensionMain (SwiftPM has no .appex product type)
  MpalFilePreview/App.swift                       host app: holds the extension, registers it, shows status
  mpal2html/main.swift                            command-line tool for testing
Bundle/                                           Info.plists + extension entitlements
Examples/Percussion_Sticking.mpal
build_app.sh                                      build + bundle + sign → dist/MpalFilePreview.zip
install_mac.sh                                    build_app.sh + install + register
.github/workflows/build.yml                       CI build, release asset on v* tags
```

SwiftPM can't build `.app` or `.appex` bundles, so `build_app.sh` assembles
`MpalFilePreview.app/Contents/{MacOS,Info.plist,PlugIns/MpalFilePreviewExtension.appex}` by hand.
It then signs the extension (sandboxed) and the app. When the app is opened, it registers the extension
with `pluginkit`, which is the same step `install_mac.sh` takes.

## File format

An `.mpal` is a zip archive. `META-INF/container.xml` points to the root file, usually `palette.xml`.
That file holds a `<Palette>` with `<Cell name="…">` children, each wrapping one element (`<Sticking>`,
`<Articulation>`, …). The preview shows each element's `<text>` if it has one, otherwise its `<subtype>`,
otherwise the element name, and uses `<family>` as the font if one is given.

## Troubleshooting

- **No preview:** open the app and click **Reset Quick Look**. Then check that **MPAL File Preview** is
  turned on under Quick Look in System Settings › Extensions (the app's **Extension Settings…** button).
- **Wrong file type:** run `mdls -name kMDItemContentType file.mpal`. It should print
  `local.mpal-file-preview.mpal`. If another app has claimed `.mpal` under a different identifier, add that
  identifier to `QLSupportedContentTypes` in `Bundle/Extension-Info.plist` and rebuild.
- **Is the extension registered?** Check with `pluginkit -mv -p com.apple.quicklook.preview | grep -i mpal`.
- **Logs:** `log stream --predicate 'process == "MpalFilePreviewExtension"'`

## License

MIT, see [LICENSE](LICENSE).
