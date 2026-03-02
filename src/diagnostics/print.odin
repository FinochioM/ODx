package diagnostics

import "core:fmt"
import "core:strings"

print_diagnostics :: proc(diagnostics: []Diagnostic) {
    for d in diagnostics {
        fmt.printfln("%s: %s:%d:%d", d.level, d.file, d.line, d.col)
        fmt.printfln("  %s", d.message)
    }
}
