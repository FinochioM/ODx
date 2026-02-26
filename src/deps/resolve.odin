package deps

import "core:fmt"
import "core:os"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"
import "src:cache"
import "src:module"

Resolved :: struct {
    name: string,
    path: string,
    sha:  string,
}

resolve_all :: proc(mod: module.Module, manifest: module.Manifest, allocator := context.allocator) -> (resolved: []Resolved, ok: bool) {
    if len(manifest.deps) == 0 {
        return nil, true
    }

    out := make([dynamic]Resolved, allocator)
    
    for name, dep in manifest.deps {
        r, dep_ok := resolve_one(name, dep, mod.root, allocator)
        if !dep_ok {
            delete(out)
            return nil, false
        }

        append(&out, r)
    }

    return out[:], true
}

@(private)
resolve_one :: proc(
    name:      string,
    dep:       module.Dep,
    mod_root:  string,
    allocator := context.allocator,
) -> (Resolved, bool) {
    switch dep.kind {
    case .Path:
        return resolve_path(name, dep.url, mod_root, allocator)
    case .Git:
        return resolve_git(name, dep.url, dep.rev, allocator)
    }
    return {}, false
}

@(private)
resolve_path :: proc(
    name:     string,
    rel:      string,
    mod_root: string,
    allocator := context.allocator,
) -> (Resolved, bool) {
    abs := rel if filepath.is_abs(rel) else filepath.join({mod_root, rel}, allocator)

    if !os.exists(abs) {
        fmt.eprintfln("odx: path dep '%s': directory not found: '%s'", name, abs)
        return {}, false
    }

    return Resolved{name = name, path = abs, sha = ""}, true
}

@(private)
resolve_git :: proc(
    name:     string,
    url:      string,
    rev:      string,
    allocator := context.allocator,
) -> (Resolved, bool) {
    if rev == "" {
        fmt.eprintfln("odx: git dep '%s': rev is required", name)
        return {}, false
    }

    cache_dir := cache.get_cache_dir(context.temp_allocator)
    url_hash  := cache.hash_string(url, context.temp_allocator)
    dest      := filepath.join({cache_dir, "v0", "deps", "git", url_hash}, allocator)

    if !os.exists(dest) {
        fmt.printfln("odx: cloning '%s'...", url)
        if !git_exec({"git", "clone", "--quiet", url, dest}) {
            fmt.eprintfln("odx: failed to clone '%s'", url)
            return {}, false
        }
    }

    if !git_exec({"git", "-C", dest, "checkout", "--quiet", rev}) {
        fmt.eprintfln("odx: dep '%s': failed to checkout '%s'", name, rev)
        return {}, false
    }

    sha, sha_ok := git_output({"git", "-C", dest, "rev-parse", "HEAD"})
    if !sha_ok {
        fmt.eprintfln("odx: dep '%s': failed to resolve SHA", name)
        return {}, false
    }

    return Resolved{name = name, path = dest, sha = strings.trim_space(sha)}, true
}

@(private)
git_exec :: proc(argv: []string) -> bool {
    state, _, _, err := os2.process_exec({command = argv}, context.temp_allocator)
    return err == nil && state.exit_code == 0
}

@(private)
git_output :: proc(argv: []string, allocator := context.allocator) -> (string, bool) {
    state, stdout, _, err := os2.process_exec({command = argv}, allocator)
    if err != nil || state.exit_code != 0 {
        return "", false
    }
    return string(stdout), true
}
