const std = @import("std");

// Game State
const State = struct {
    pressure: f32, // Bars
    temperature: f32, // Celsius
    water_level: f32, // Liters (0-2)
    heater_on: bool,
    pump_primed: bool,
    filter_locked: bool,
    coffee_loaded: bool,
    cup_placed: bool,
    
    // Failure flags
    exploded: bool,
    melted: bool,
    electrocuted: bool,
    success: bool,
};

var state = State{
    .pressure = 1.0, // Atmospheric
    .temperature = 20.0, // Room temp
    .water_level = 0.5,
    .heater_on = false,
    .pump_primed = false,
    .filter_locked = false,
    .coffee_loaded = false,
    .cup_placed = false,
    .exploded = false,
    .melted = false,
    .electrocuted = false,
    .success = false,
};

// Buffers for communication with JS
var output_buffer: [4096]u8 = undefined;
var output_len: usize = 0;
var input_buffer: [256]u8 = undefined; // Small buffer for commands
var image_buffer: [4096]u8 = undefined;
var image_len: usize = 0;
var tts_buffer: [2048]u8 = undefined; // Bark prompts
var tts_len: usize = 0;
var sfx_buffer: [2048]u8 = undefined; // LDM2 prompts
var sfx_len: usize = 0;

const AESTHETIC_PROMPT = "hyper-realistic 35mm photo of a 1930s soviet industrial coffee machine, heavy steel, analog gauges, bakelite handles, cyrillic text labeled 'КОФЕ', rusty pipes, steam, dimly lit factory background";

pub export fn get_output_ptr() *u8 {
    return &output_buffer[0];
}

pub export fn get_output_len() usize {
    return output_len;
}

pub export fn get_input_ptr() *u8 {
    return &input_buffer[0];
}

pub export fn get_image_ptr() *u8 {
    return &image_buffer[0];
}

pub export fn get_image_len() usize {
    return image_len;
}

pub export fn get_tts_ptr() *u8 {
    return &tts_buffer[0];
}

pub export fn get_tts_len() usize {
    return tts_len;
}

pub export fn get_sfx_ptr() *u8 {
    return &sfx_buffer[0];
}

pub export fn get_sfx_len() usize {
    return sfx_len;
}

fn set_output(comptime fmt: []const u8, args: anytype) void {
    const s = std.fmt.bufPrint(&output_buffer, fmt, args) catch "Error";
    output_len = s.len;
}

fn set_image(comptime fmt: []const u8, args: anytype) void {
    var temp_buf: [1024]u8 = undefined;
    const modifier = std.fmt.bufPrint(&temp_buf, fmt, args) catch "error";
    const final = std.fmt.bufPrint(&image_buffer, "{s}, {s}", .{AESTHETIC_PROMPT, modifier}) catch "Error";
    image_len = final.len;
}

fn set_tts(comptime fmt: []const u8, args: anytype) void {
    const s = std.fmt.bufPrint(&tts_buffer, fmt, args) catch "Error";
    tts_len = s.len;
}

fn set_sfx(comptime fmt: []const u8, args: anytype) void {
    var temp_buf: [1024]u8 = undefined;
    const desc = std.fmt.bufPrint(&temp_buf, fmt, args) catch "error";
    const final = std.fmt.bufPrint(&sfx_buffer, "SFX: {s} (64 iterations, high quality, ldm2)", .{desc}) catch "Error";
    sfx_len = final.len;
}

pub export fn init() void {
    set_output(
        \\MODEL: KOF-34-B (HEAVY INDUSTRY VARIANT)
        \\STATUS: STANDBY
        \\
        \\AVAILABLE COMMANDS:
        \\- status      Check gauges
        \\- fill        Add water to tank
        \\- load        Load coffee grounds
        \\- tamp        Tamp grounds
        \\- lock        Lock portafilter
        \\- cup         Place cup
        \\- prime       Prime the pump (CRITICAL BEFORE HEAT)
        \\- heat        Toggle heater
        \\- extract     Engage extraction pump
        \\- vent        Emergency pressure release
        \\- wait        Wait for temperature/pressure to build
        \\
        \\OPERATE WITH CAUTION. GLORY TO THE UNION.
    , .{});
    set_image("cold, inactive, dark indicator lights", .{});
    set_tts("[clears throat] Another day in the machine hall. Let's see if this old beast still breathes.", .{});
    set_sfx("low frequency industrial hum of a dormant factory", .{});
}

// Simple string comparison helper
fn eq(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub export fn run_command(len: usize) void {
    if (state.exploded or state.melted or state.electrocuted) {
        set_output("MACHINE DESTROYED. REPAIR IMPOSSIBLE. NKVD NOTIFIED.", .{});
        return;
    }
    
    // Use the global input buffer
    const cmd_raw = input_buffer[0..len];
    
    // Simulate physics step on every command
    tick_physics();
    
    if (check_failures()) return;

    if (eq(cmd_raw, "status")) {
        set_output(
            \\--- GAUGES ---
            \\PRESSURE: {d:.1} BAR
            \\TEMP:     {d:.1} C
            \\WATER:    {d:.1} L
            \\HEATER:   {s}
            \\PUMP:     {s}
            \\FILTER:   {s}
        , .{
            state.pressure,
            state.temperature,
            state.water_level,
            if (state.heater_on) "ON" else "OFF",
            if (state.pump_primed) "PRIMED" else "DRY",
            if (state.filter_locked) "LOCKED" else if (state.coffee_loaded) "LOADED" else "EMPTY"
        });
        set_image("close up of gauges, needle at {d:.1} bar, {d:.1} C", .{state.pressure, state.temperature});
        set_tts("[slight laughter] Gauges are dancing. {s}", .{if (state.pressure > 10) "It's getting lively." else "Still a bit quiet."});
        set_sfx("metallic clinking of analog gauge needles hitting pins", .{});
    } else if (eq(cmd_raw, "fill")) {
        if (state.water_level >= 2.0) {
            set_output("TANK FULL. WATER SPILLS ON FLOOR.", .{});
            set_tts("[gasps] Watch it! The floor's going to be a lake.", .{});
            set_sfx("loud splashing of water on cold concrete floor", .{});
        } else {
            state.water_level += 0.5;
            set_output("WATER ADDED. LEVEL: {d:.1}L", .{state.water_level});
            set_image("water being poured into rusty metal tank, ripples", .{});
            set_tts("[sigh] Dusty tank. Hope the filter catches the rust.", .{});
            set_sfx("resonant glugging of water entering a hollow metal vessel", .{});
        }
    } else if (eq(cmd_raw, "vent")) {
         state.pressure = 1.0;
         set_output("HISS!!!! STEAM VENTS. PRESSURE NORMALIZED.", .{});
         set_image("massive cloud of white steam erupting, obscuring machine", .{});
         set_tts("[coughing] Too much steam! I can't see the floor.", .{});
         set_sfx("violent high-pitched hissing of pressurized steam escaping a narrow valve", .{});
    } else if (eq(cmd_raw, "heat")) {
        state.heater_on = !state.heater_on;
        if (state.heater_on) {
            set_output("HEATER ENGAGED. HUMMING SOUND.", .{});
            set_image("red warning light glowing, heat waves distortion", .{});
            set_tts("[clears throat] It's humming. Let the fire begin.", .{});
            set_sfx("deep 50Hz electrical hum with rising metallic expansion pings", .{});
        } else {
            set_output("HEATER DISENGAGED.", .{});
            set_image("red light off, cooling metal", .{});
            set_tts("[sigh] Better safe than sorry. Let it cool.", .{});
            set_sfx("sharp click of a heavy bakelite toggle switch", .{});
        }
    } else if (eq(cmd_raw, "prime")) {
        if (state.water_level <= 0.1) {
             set_output("CANNOT PRIME. TANK EMPTY.", .{});
             set_tts("[annoyed] I can't prime a dry pump. Use your head.", .{});
             set_sfx("strained sound of a pump sucking air and gravel", .{});
        } else {
            state.pump_primed = true;
            state.pressure += 0.5;
            set_output("PUMP PRIMED. HYDRAULICS ENGAGED.", .{});
            set_image("vibrating machinery, pipes shuddering", .{});
            set_tts("[laughter] Listen to that rattle. It's alive.", .{});
            set_sfx("heavy mechanical thud followed by rhythmic surging of fluid", .{});
        }
    } else if (eq(cmd_raw, "load")) {
        state.coffee_loaded = true;
        set_output("COFFEE GROUNDS LOADED.", .{});
        set_image("dark coffee grounds in metal basket", .{});
        set_tts("Grounds are in. Smells like coffee... and oil.", .{});
        set_sfx("dry scraping of coffee grounds against a brass container", .{});
    } else if (eq(cmd_raw, "tamp")) {
         if (!state.coffee_loaded) {
             set_output("NOTHING TO TAMP.", .{});
             set_tts("[hesitation] I can't tamp air, comrade.", .{});
             set_sfx("hollow metallic ring of a tamper hitting an empty basket", .{});
         } else {
             set_output("GROUNDS TAMPED FIRMLY.", .{});
             set_image("smooth flat coffee puck surface", .{});
             set_tts("Solid as a brick. Just how we like it.", .{});
             set_sfx("dull heavy thud of compressed coffee grounds", .{});
         }
    } else if (eq(cmd_raw, "lock")) {
         if (state.filter_locked) {
             state.filter_locked = false;
             set_output("PORTAFILTER REMOVED.", .{});
             set_tts("Unlock. Clang.", .{});
             set_sfx("grinding of heavy brass threads followed by a resonant metal impact", .{});
         } else {
             state.filter_locked = true;
             set_output("PORTAFILTER LOCKED INTO GROUPHEAD with a CLANK.", .{});
             set_image("heavy brass handle locked in place, industrial aesthetics", .{});
             set_tts("Locked and loaded. Don't slip.", .{});
             set_sfx("forceful metallic lock-in sound, heavy and final", .{});
         }
    } else if (eq(cmd_raw, "cup")) {
        state.cup_placed = true;
        set_output("PORCELAIN CUP PLACED.", .{});
        set_image("small chipped white cup with blue rim under nozzle", .{});
        set_tts("The little porcelain survivor is in place.", .{});
        set_sfx("delicate clink of porcelain on a cast iron grate", .{});
    } else if (eq(cmd_raw, "wait")) {
        set_output("TIME PASSES...", .{});
        tick_physics();
        set_image("clock ticking, steam rising slowly", .{});
        set_tts("[sigh] Standing around is half the job.", .{});
        set_sfx("rhythmic mechanical ticking of a clockwork timer", .{});
    } else if (eq(cmd_raw, "extract")) {
        attempt_extraction();
    } else {
        set_output("UNKNOWN COMMAND. DO NOT DEVIATE FROM PROTOCOL.", .{});
        set_sfx("harsh buzzing of a fail-state alarm", .{});
    }
    
   _ = check_failures();
}

fn tick_physics() void {
    if (state.heater_on) {
        state.temperature += 15.0;
        if (state.pump_primed) {
             state.pressure += 2.5; 
        } else {
             state.temperature += 30.0;
        }
    } else {
        if (state.temperature > 20.0) state.temperature -= 2.0;
        if (state.pressure > 1.0) state.pressure -= 0.5;
    }
    if (state.pressure < 1.0) state.pressure = 1.0;
}

fn attempt_extraction() void {
    if (!state.cup_placed) {
        set_output("NO CUP! HOT COFFEE SPRAYS EVERYWHERE.", .{});
        set_image("black liquid spraying on floor and boots, mess", .{});
        set_tts("[screams] AHH! MY BOOTS! WHERE WAS THE CUP?", .{});
        set_sfx("violent splashing of hot liquid and a distant scream", .{});
        return;
    }
    
    if (!state.filter_locked or !state.coffee_loaded) {
         set_output("HOT WATER SPRAYS FROM GROUPHEAD. BURNS!", .{});
         set_image("scalding clear water splashing violently", .{});
         set_tts("[gasp] Scalding! I forgot the filter!", .{});
         set_sfx("high pressure water jet hitting a metal tray with a hiss", .{});
         return;
    }
    
    if (state.pressure < 8.0) {
        set_output("PRESSURE TOO LOW ({d:.1} BAR). WEAK BROWN WATER DISPENSED.", .{state.pressure});
        set_image("pale translucent brown liquid in cup, sad", .{});
        set_tts("[sigh] Dishwater. I need more pressure.", .{});
        set_sfx("thin weak trickling of water into a cup", .{});
        return;
    }
    
    if (state.pressure > 12.0) {
        set_output("PRESSURE TOO HIGH! GROUPHEAD GASKET BLOWS OUT.", .{});
        set_image("rubber seal hanging loose, steam hissing aggressively", .{});
        set_tts("[scared] WHOA! The gasket! I pushed it too far.", .{});
        set_sfx("explosive pop followed by intense uncontrolled steam roar", .{});
        return;
    }
    
    if (state.temperature < 90.0) {
         set_output("TOO COLD. SOUR ESPRESSO.", .{});
         set_image("no crema, oily looking liquid", .{});
         set_tts("Ugh, sour. Tastes like battery acid.", .{});
         set_sfx("irregular sputtering of cool liquid", .{});
         return;
    }
    
    if (state.temperature > 105.0) {
         set_output("BURNT! BITTER SLUDGE.", .{});
         set_image("black bubbling tar in cup", .{});
         set_tts("[clears throat] It's charred. I can feel my throat melting.", .{});
         set_sfx("boiling bubbling sounds of an over-extracted liquid", .{});
         return;
    }
    
    state.success = true;
    set_output("PERFECT EXTRACTION. THICK CREMA. GLORY TO THE STATE.", .{});
    set_image("perfect espresso shot, thick hazelnut crema, steam curling beautifully", .{});
    set_tts("[laughter] Look at that crema! Victory is mine.", .{});
    set_sfx("smooth viscous pouring sound, deep mechanical drone, ultimate satisfaction", .{});
}

fn check_failures() bool {
    if (state.pressure > 50.0) {
        state.exploded = true;
        set_output("CRITICAL FAILURE: BOILER RUPTURE. EXPLOSION IMMINENT.", .{});
        set_image("shattered metal, room filled with debris and smoke, destroyed machine", .{});
        set_tts("[screams] RUN! SHE'S GONNA BLOW!", .{});
        set_sfx("thunderous metallic explosion, tearing steel, shattering glass", .{});
        return true;
    }
    if (state.temperature > 250.0) {
        state.melted = true;
        set_output("CORE MELTDOWN. HEATING ELEMENT FUSED TO CHASSIS.", .{});
        set_image("glowing red metal dropping molten slag, black smoke", .{});
        set_tts("[gasp] It's glowing... the floor is melting. Help.", .{});
        set_sfx("low-pitched sizzling of molten metal, crackling fire", .{});
        return true;
    }
    if (state.pump_primed and state.water_level <= 0.0) {
        set_output("PUMP RAN DRY AND CAUGHT FIRE.", .{});
        state.melted = true;
        set_image("pump housing engulfed in flames, electrical sparks", .{});
        set_tts("[panic] Fire! The pump is screaming and burning!", .{});
        set_sfx("high-pitched mechanical screech ending in an electrical pop and fire crackle", .{});
        return true;
    }
    return false;
}
