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

    sources, src_ok := module.collect_sources(mod.root)
    if !src_ok {
        fmt.eprintln("odx: failed to collect sources")
        return
    }

    fmt.printfln("sources: %d .odin file(s)", len(sources))
    for s in sources {
        fmt.printfln("  %s", s)
    }
}
