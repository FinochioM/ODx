package commands

import "core:fmt"
import "src:module"

list :: proc(path: string) {
    mod, ok := module.resolve(path)

    if !ok {
        return
    }

    fmt.printfln("module: %s", mod.name)
    fmt.printfln("root: %s", mod.root)

    if mod.has_manifest {
        fmt.printfln("manifest: odx.toml (found)")
    } else {
        fmt.printfln("manifest: none (ad-hoc mode)")
    }
}
