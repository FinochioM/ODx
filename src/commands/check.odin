package commands

import "core:fmt"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"
import "src:module"

Check_Args :: struct {
    path:       string,
    profile:    string,
    target:     string,
    verbose:    bool,
    cli_defines: []string,
    cli_flags: []string,
}

check :: proc(a: Check_Args) -> bool {
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

    odin_cmd := "odin"
    if has_manifest && manifest.build.odin_cmd != "" {
        odin_cmd = manifest.build.odin_cmd
    }

    profile_flags:   []string
    profile_defines: map[string]string

    if has_manifest {
        if p, found := manifest.profiles[profile]; found {
            profile_flags   = p.flags
            profile_defines = p.defines
        }
    }

    flags, defines := merge_profile_overrides(
        profile_flags,
        profile_defines,
        a.cli_flags,
        a.cli_defines,
    )

    argv := make([dynamic]string)
    defer delete(argv)

    append(&argv, odin_cmd, "check", entry)

    for flag in flags {
        append(&argv, flag)
    }
    for k, v in defines {
        append(&argv, fmt.aprintf("-define:%s=%s", k, v))
    }

    if has_manifest {
        for col_name, rel_path in manifest.build.collections {
            abs_path := filepath.join({mod.root, rel_path})
            append(&argv, fmt.aprintf("-collection:%s=%s", col_name, abs_path))
        }
    }

    if a.verbose {
        fmt.println(strings.join(argv[:], " "))
    }

    state, stdout, stderr, run_err := os2.process_exec({command = argv[:]}, context.allocator)
    if run_err != nil {
        fmt.eprintfln("odx: failed to launch odin: %v", run_err)
        return false
    }

    if len(stdout) > 0 {
        fmt.print(string(stdout))
    }

    if state.exit_code != 0 {
        if len(stderr) > 0 {
            fmt.eprint(string(stderr))
        }

        fmt.eprintfln("odx: check failed (exit code %d)", state.exit_code)
        return false
    }

    fmt.println("odx: check passed")
    return true
}
