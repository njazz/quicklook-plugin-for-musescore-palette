// swift-tools-version:5.9
// SwiftPM can't produce .app/.appex bundles itself; install_mac.sh wraps the built executables.
import PackageDescription

let package = Package(
    name: "MpalFilePreview",
    platforms: [.macOS(.v12)], // data-based QLPreviewProvider needs macOS 12+
    targets: [
        // .mpal (zip) -> palette XML -> HTML. No Quick Look dependency, so it's testable via the CLI.
        .target(name: "MpalCore"),
        // Quick Look preview extension (becomes MpalFilePreviewExtension.appex).
        .executableTarget(name: "MpalFilePreviewExtension", dependencies: ["MpalCore"]),
        // Host app that carries the extension and declares the .mpal type (becomes MpalFilePreview.app).
        .executableTarget(name: "MpalFilePreview"),
        // Dev tool: `swift run mpal2html file.mpal > out.html`
        .executableTarget(name: "mpal2html", dependencies: ["MpalCore"]),
    ]
)
