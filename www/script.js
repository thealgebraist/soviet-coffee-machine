let wasmMemory;
let wasmInstance;

async function loadWasm() {
    try {
        const response = await fetch('game.wasm');
        const bytes = await response.arrayBuffer();
        const obj = await WebAssembly.instantiate(bytes, {
            env: {
                // If we need imports, they go here
            }
        });

        wasmInstance = obj.instance;
        wasmMemory = wasmInstance.exports.memory;

        // Initialize game
        if (wasmInstance.exports.init) {
            wasmInstance.exports.init();
            updateInterface();
        }

    } catch (e) {
        console.error("WASM Load Failed:", e);
        addToLog("CRITICAL SYSTEM FAILURE: WASM MODULE MISSING.", "system-output");
    }
}

function readString(ptrFn, lenFn) {
    const ptr = ptrFn();
    const len = lenFn();
    const bytes = new Uint8Array(wasmMemory.buffer, ptr, len);
    return new TextDecoder("utf-8").decode(bytes);
}

function updateInterface() {
    const output = readString(wasmInstance.exports.get_output_ptr, wasmInstance.exports.get_output_len);
    const imagePrompt = readString(wasmInstance.exports.get_image_ptr, wasmInstance.exports.get_image_len);
    const ttsPrompt = readString(wasmInstance.exports.get_tts_ptr, wasmInstance.exports.get_tts_len);
    const sfxPrompt = readString(wasmInstance.exports.get_sfx_ptr, wasmInstance.exports.get_sfx_len);

    addToLog(output, "system-output");

    // Update visuals
    document.getElementById("image-prompt-text").innerText = imagePrompt;
    document.getElementById("tts-prompt-text").innerText = ttsPrompt;
    document.getElementById("sfx-prompt-text").innerText = sfxPrompt;
}

function addToLog(text, className) {
    const log = document.getElementById("log");
    const div = document.createElement("div");
    div.className = "log-entry " + className;
    div.innerText = text;
    log.appendChild(div);
    log.scrollTop = log.scrollHeight;
}

// Input handling
const input = document.getElementById("cmd-input");
input.addEventListener("keydown", async (e) => {
    if (e.key === "Enter") {
        const cmd = input.value.trim().toLowerCase();
        if (!cmd) return;

        addToLog("> " + cmd, "user-input");
        input.value = "";

        // Pass to WASM
        // We need to write the string into WASM memory. 
        // For simplicity in this constrained environment, we'll assume a shared buffer or just "alloc" a quick space if needed.
        // But since we didn't export `alloc` in Zig, let's just reuse the output buffer as input buffer? 
        // DANGEROUS but efficient for this toy. The Zig side reads `ptr` and `len`.
        // Actually, let's just use the end of memory or export a dedicated input buffer?
        // Let's modify Zig to be safer? 
        // BETTER: Export `get_output_ptr` and use that for input too? No, it might overwrite output we want to read?
        // Wait, `run_command` takes a PTR and Length. We need a place to put it.
        // Let's just create a small TypedArray in JS on top of the WASM memory at a known offset if we knew it?
        // Unsafe.
        // Correct way: Export an `alloc` or `input_buffer` from Zig.

        // Let's assume we can write to the *start* of the output buffer for Input, 
        // process it, and then Zig writes the Output to the same buffer?
        // Zig `run_command` reads, then inside it calls `set_output` which writes.
        // If input and output share memory, we must be careful not to overwrite input before reading?
        // In `run_command`, we read `cmd_raw` first thing. So it should be fine.

        // Write to dedicated input buffer
        const ptr = wasmInstance.exports.get_input_ptr();
        // Limit to 256 bytes
        const buf = new Uint8Array(wasmMemory.buffer, ptr, 256);
        const encoder = new TextEncoder();
        const encoded = encoder.encode(cmd.substring(0, 255));
        buf.set(encoded);

        wasmInstance.exports.run_command(encoded.length);

        updateInterface();
    }
});

loadWasm();
