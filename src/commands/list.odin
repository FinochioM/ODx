package commands

import "core:fmt"
import "src:module"
import "core:path/filepath"

list :: proc(path: string) {
    mod, ok := module.resolve(path)

    if !ok {
        return
    }

    fmt.printfln("module: %s", mod.name)
    fmt.printfln("root: %s", mod.root)

    if mod.has_manifest {
        fmt.printfln("manifest: odx.toml (found)")
        manifest_path := filepath.join({mod.root, "odx.toml"})
        if m, mok := module.load_manifest(manifest_path); mok {
            print_manifest(m)
        }
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

@(private)
print_manifest :: proc(m: module.Manifest) {
    if m.name != "" do fmt.printfln("   name:   %s", m.name)
    if m.out_dir != "" do fmt.printfln("    out_dir:    %s", m.out_dir)
    if m.entry != "" do fmt.printfln("  entry:  %s", m.entry)

    fmt.printfln("  odin:   %s", m.build.odin_cmd)
    fmt.printfln("  profile:    %s", m.build.default_profile)
    fmt.printfln("  target: %s", m.build.default_target)

    if len(m.profiles) > 0 {
        fmt.println("   profiles:")
        for name, p in m.profiles {
            fmt.printfln("  %s: flags=%v", name, p.flags)
        }
    }

    if len(m.tasks) > 0 {
        fmt.println("   tasks:")
        for name, t in m.tasks {
            fmt.printfln("  %s: cmd=%v", name, t.cmd)
        }
    }
}
