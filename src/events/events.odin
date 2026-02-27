package events

import "core:encoding/json"
import "core:fmt"
import "core:time"

@(private)
enabled: bool

enable :: proc() {
    enabled = true
}

is_enabled :: proc() -> bool {
    return enabled
}

Task_Started :: struct {
    event:   string `json:"event"`,
    task: string `json:"task"`,
    time:   string `json:"time"`,
}

Task_Finished :: struct {
    event:      string `json:"event"`,
    task:       string `json:"task"`,
    elapsed_ms: f64    `json:"elapsed_ms"`,
    success:    bool   `json:"success"`,
}

Cache_Hit :: struct {
    event: string `json:"event"`,
    task:  string `json:"task"`,
}

Cache_Miss :: struct {
    event: string `json:"event"`,
    task: string `json:"task"`,
}

Command_Exec :: struct {
    event:  string   `json:"event"`,
    task:    string   `json:"task"`,
    command: []string `json:"command"`,
}

Diagnostic :: struct {
    event:   string `json:"event"`,
    level: string `json:"level"`,
    message: string `json:"message"`,
}

Event :: union {
    Task_Started,
    Task_Finished,
    Cache_Hit,
    Cache_Miss,
    Command_Exec,
    Diagnostic,
}

emit :: proc(e: Event) {
    if !enabled do return

    data, err := json.marshal(e, allocator = context.temp_allocator)
    if err != nil do return

    fmt.println(string(data))
}

now_string :: proc(allocator := context.allocator) -> string {
    t := time.now()
    y, mo, d  := time.date(t)
    h, mi, s  := time.clock(t)
    return fmt.aprintf("%4d-%02d-%02dT%02d:%02d:%02dZ", y, int(mo), d, h, mi, s, allocator = allocator)
}
