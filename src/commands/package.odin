package commands

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "src:module"
import "src:archive"

Pkg_Args :: struct {
    path:        string,
    profile:     string,
    target:      string,
    verbose:     bool,
    cli_defines: []string,
    cli_flags:   []string,
}

pkg :: proc(a: Pkg_Args) -> bool {
    bin_path, ok := build_binary({
        path        = a.path,
        profile     = a.profile,
        target      = a.target,
        verbose     = a.verbose,
        cli_defines = a.cli_defines,
        cli_flags   = a.cli_flags,
    })
    if !ok do return false

    mod, mod_ok := module.resolve(a.path)
    if !mod_ok do return false

    manifest: module.Manifest
    has_manifest := false

    if mod.has_manifest {
        manifest_path := filepath.join({mod.root, "odx.toml"})
        manifest, has_manifest = module.load_manifest(manifest_path)
        if !has_manifest do return false
    }

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

    out_dir := filepath.join({mod.root, manifest.out_dir, target, profile})

    files := make([dynamic]string)
    defer delete(files)
    append(&files, bin_path)

    if has_manifest && len(manifest.pkg.extras) > 0 {
        var_map := build_template_vars(mod, manifest)
        defer delete(var_map)

        extras, glob_ok := resolve_globs(manifest.pkg.extras, mod.root, var_map)
        if !glob_ok {
            fmt.eprintln("odx: failed to resolve package extras")
            return false
        }
        for f in extras {
            append(&files, f)
        }
    }

    archive_name := fmt.aprintf("%s-%s-%s", name, target, profile)
    archive_path := filepath.join({out_dir, archive_name})

    when ODIN_OS == .Windows {
        archive_path = strings.concatenate({archive_path, ".zip"})
    } else {
        archive_path = strings.concatenate({archive_path, ".tar.gz"})
    }

    if a.verbose {
        fmt.printfln("odx: packaging %d file(s) into %s", len(files), archive_path)
        for f in files {
            fmt.printfln("  %s", f)
        }
    }

    if !archive.write(archive_path, files[:], mod.root) {
        fmt.eprintfln("odx: failed to create archive '%s'", archive_path)
        return false
    }

    fmt.printfln("odx: packaged %s", archive_path)
    return true
}
