// Usage: swift run mpal2html Examples/Percussion_Sticking.mpal > out.html && open out.html
import Foundation
import MpalCore

let args = CommandLine.arguments
guard args.count == 2 else {
    FileHandle.standardError.write(Data("usage: mpal2html file.mpal > out.html\n".utf8))
    exit(2)
}
do {
    print(try Mpal.html(fromArchive: Data(contentsOf: URL(fileURLWithPath: args[1]))))
} catch {
    FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
    exit(1)
}
