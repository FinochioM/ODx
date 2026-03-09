package archive

import "core:fmt"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"

write :: proc(archive_path: string, files: []string, root: string) -> bool {
    when ODIN_OS == .Windows {
        return write_zip(archive_path, files, root)
    } else {
        return write_tar_gz(archive_path, files, root)
    }
}

@(private)
write_tar_gz :: proc(archive_path: string, files: []string, root: string) -> bool {
    argv := make([dynamic]string)
    defer delete(argv)

    append(&argv, "tar", "-czf", archive_path)

    for f in files {
        rel, ok := filepath.rel(root, f, context.temp_allocator)
        if ok == .None {
            append(&argv, rel)
        } else {
            append(&argv, f)
        }
    }

    state, _, stderr, err := os2.process_exec(
        {command = argv[:], working_dir = root},
        context.allocator,
    )

    if err != nil || state.exit_code != 0 {
        if len(stderr) > 0 {
            fmt.eprint(string(stderr))
        }
        return false
    }

    return true
}

@(private)
write_zip :: proc(archive_path: string, files: []string, root: string) -> bool {
    argv := make([dynamic]string)
    defer delete(argv)

    append(&argv, "powershell", "-Command")

    file_list := make([dynamic]string)
    defer delete(file_list)
    for f in files {
        rel, ok := filepath.rel(root, f, context.temp_allocator)
        if ok == .None {
            append(&file_list, rel)
        } else {
            append(&file_list, f)
        }
    }

    joined := strings.join(file_list[:], "','")
    cmd := fmt.aprintf("Compress-Archive -Path '%s' -DestinationPath '%s' -Force", joined, archive_path)
    append(&argv, cmd)

    state, _, stderr, err := os2.process_exec(
        {command = argv[:], working_dir = root},
        context.allocator,
    )

    if err != nil || state.exit_code != 0 {
        if len(stderr) > 0 {
            fmt.eprint(string(stderr))
        }
        return false
    }

    return true
}
