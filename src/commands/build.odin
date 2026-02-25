package commands

import "core:fmt"
import "core:os"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"
import "src:module"

Build_Args :: struct {
    path:       string,
    profile:    string,
    target:     string,
    out:        string,
    verbose:    bool,
}

build :: proc(a: Build_Args) -> bool {
    mod, ok := module.resolve(a.path)
    if !ok do return false

    manifest: module.Manifest
    has_manifest := false

    if mod.has_manifest {
        manifest_path := filepath.join({mod.root, "odx.toml"})
        manifest, has_manifest = module.load_manifest(manifest_path)
        if !has_manifest do return false
    }

    entry, entry_ok := module.resolve_entry(mod, manifest, has_manifest)
    if !entry_ok do return false

    profile := a.profile
    if profile == "" {
        profile = manifest.build.default_profile if has_manifest else "dev"
    }

    target := a.target
    if target == "" {
        target = manifest.build.default_target if has_manifest else "host"
    }

    name := mod.name
    if has_manifest && manifest.name != "" {
        name = manifest.name
    }

    out_dir := "build"
    if has_manifest && manifest.out_dir != "" {
        out_dir = manifest.out_dir
    }

    bin_dir := filepath.join({mod.root, out_dir, target, profile, "bin"})
    if !make_dir_all(bin_dir) {
        fmt.eprintfln("odx: could not create output dir '%s'", bin_dir)
        return false
    }

    bin_name := name
    when ODIN_OS == .Windows {
        bin_name = strings.concatenate({name, ".exe"})
    }

    bin_path := a.out if a.out != "" else filepath.join({bin_dir, bin_name})

    odin_cmd := "odin"
    if has_manifest && manifest.build.odin_cmd != "" {
        odin_cmd = manifest.build.odin_cmd
    }

    argv := make([dynamic]string)
    defer delete(argv)

    append(&argv, odin_cmd, "build", entry, fmt.aprintf("-out:%s", bin_path))

    if has_manifest {
        if p, found := manifest.profiles[profile]; found {
            for flag in p.flags {
                append(&argv, flag)
            }
            for k, v in p.defines {
                append(&argv, fmt.aprintf("-define:%s=%s", k, v))
            }
        }

        for name, rel_path in manifest.build.collections {
            abs_path := filepath.join({mod.root, rel_path})
            append(&argv, fmt.aprintf("-collection:%s=%s", name, abs_path))
        }
    } else if profile == "dev" {
        append(&argv, "-debug")
    }

    if a.verbose {
        fmt.println(strings.join(argv[:], " "))
    }

    state, _, stderr, run_err := os2.process_exec({command = argv[:]}, context.allocator)
    if run_err != nil {
        fmt.eprintfln("odx: failed to lunch odin: %v", run_err)
        return false
    }

    if state.exit_code != 0 {
        if len(stderr) > 0 {
            fmt.eprint(string(stderr))
        }

        fmt.eprintfln("odx: build failed (exit code %d)", state.exit_code)
        return false
    }

    fmt.printfln("odx: built %s", bin_path)
    return true
}

@(private)
make_dir_all :: proc(path: string) -> bool {
    if os.exists(path) do return true

    parent := filepath.dir(path)
    if parent != path {
        if !make_dir_all(parent) do return false
    }

    err := os.make_directory(path)
    return err == os.ERROR_NONE
}
