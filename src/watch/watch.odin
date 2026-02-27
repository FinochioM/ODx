package watch

import "core:os"
import "core:time"

DEFAULT_INTERVAL :: 500 * time.Millisecond

File_Stamp :: struct {
    mtime: time.Time,
    size:  i64,
}

wait_for_change :: proc(paths: []string, interval := DEFAULT_INTERVAL) {
    before := snapshot(paths, context.temp_allocator)
    for {
        time.sleep(interval)
        after := snapshot(paths, context.temp_allocator)
        if has_changed(before, after) {
            return
        }
        before = after
    }
}

@(private)
snapshot :: proc(paths: []string, allocator := context.allocator) -> []File_Stamp {
    stamps := make([]File_Stamp, len(paths), allocator)
    for path, i in paths {
        fi, err := os.stat(path, context.temp_allocator)
        if err == os.ERROR_NONE {
            stamps[i] = {mtime = fi.modification_time, size = fi.size}
        }
    }
    return stamps
}

@(private)
has_changed :: proc(before, after: []File_Stamp) -> bool {
    if len(before) != len(after) {
        return true
    }
    for i in 0..<len(before) {
        if before[i].mtime != after[i].mtime || before[i].size != after[i].size {
            return true
        }
    }
    return false
}
