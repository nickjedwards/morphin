//! Everything the shell wants to know once, at startup, in one reply — each
//! of these used to be its own `sh -c`.

use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

use serde_json::{json, Value};

pub fn hello(init: &Value) -> Value {
    for dir in init["dirs"].as_array().into_iter().flatten().filter_map(Value::as_str) {
        let _ = fs::create_dir_all(dir);
    }
    // The runtime dir is private to the user, as the XDG spec requires.
    if let Some(dir) = init["privateDir"].as_str() {
        let _ = fs::create_dir_all(dir);
        let _ = fs::set_permissions(dir, fs::Permissions::from_mode(0o700));
    }

    json!({
        "type": "hello",
        "version": env!("CARGO_PKG_VERSION"),
        "cpuTemp": cpu_temp(Path::new("/sys/class/hwmon")),
        "kbd": keyboard_light(Path::new("/sys/class/leds")),
        "hyprpaper": is_running("hyprpaper"),
        "hyprsunset": on_path("hyprsunset"),
        "zone": resolve("/etc/localtime"),
        "wallpaperLink": init["link"].as_str().map(resolve).unwrap_or_default(),
    })
}

/// The real file behind a path, or nothing if it doesn't lead anywhere.
fn resolve(path: &str) -> String {
    fs::canonicalize(path).map(|p| p.to_string_lossy().into_owned()).unwrap_or_default()
}

/// Entries of a directory, in the order a shell glob would give them.
fn sorted(dir: &Path) -> Vec<PathBuf> {
    let mut entries: Vec<PathBuf> = fs::read_dir(dir).into_iter().flatten().flatten().map(|e| e.path()).collect();
    entries.sort();
    entries
}

fn read_trimmed(path: &Path) -> Option<String> {
    fs::read_to_string(path).ok().map(|s| s.trim().to_string())
}

/// The CPU's own temperature sensor, found by name: hwmon numbers move around.
fn cpu_temp(hwmon: &Path) -> String {
    const SENSORS: [&str; 4] = ["k10temp", "coretemp", "zenpower", "cpu_thermal"];
    sorted(hwmon)
        .into_iter()
        .filter(|dir| read_trimmed(&dir.join("name")).is_some_and(|name| SENSORS.contains(&name.as_str())))
        .map(|dir| dir.join("temp1_input"))
        .find(|input| fs::File::open(input).is_ok())
        .map(|input| input.to_string_lossy().into_owned())
        .unwrap_or_default()
}

/// The first *kbd_backlight LED and how many levels it has.
fn keyboard_light(leds: &Path) -> Value {
    for dir in sorted(leds) {
        let Some(device) = dir.file_name().and_then(|n| n.to_str()) else { continue };
        if !device.contains("kbd_backlight") {
            continue;
        }
        if let Some(max) = read_trimmed(&dir.join("max_brightness")).and_then(|s| s.parse::<u64>().ok()) {
            return json!({ "device": device, "max": max });
        }
    }
    Value::Null
}

/// Like `pgrep -x`.
fn is_running(name: &str) -> bool {
    sorted(Path::new("/proc"))
        .into_iter()
        .filter(|p| p.file_name().and_then(|n| n.to_str()).is_some_and(|n| n.bytes().all(|b| b.is_ascii_digit())))
        .any(|p| read_trimmed(&p.join("comm")).as_deref() == Some(name))
}

/// Like `command -v`.
fn on_path(program: &str) -> bool {
    std::env::var_os("PATH").is_some_and(|path| {
        std::env::split_paths(&path).any(|dir| {
            fs::metadata(dir.join(program)).is_ok_and(|m| m.is_file() && m.permissions().mode() & 0o111 != 0)
        })
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn scratch(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("morpher-probe-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn finds_the_cpu_sensor_by_name() {
        let root = scratch("hwmon");
        for (dir, name) in [("hwmon0", "nvme"), ("hwmon1", "k10temp"), ("hwmon2", "coretemp")] {
            fs::create_dir_all(root.join(dir)).unwrap();
            fs::write(root.join(dir).join("name"), format!("{name}\n")).unwrap();
            fs::write(root.join(dir).join("temp1_input"), "41000\n").unwrap();
        }
        assert_eq!(cpu_temp(&root), root.join("hwmon1/temp1_input").to_string_lossy());
        assert_eq!(cpu_temp(&root.join("nothing")), "");
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn finds_the_keyboard_light() {
        let root = scratch("leds");
        for (dir, max) in [("input3::capslock", "1"), ("chromeos::kbd_backlight", "100")] {
            fs::create_dir_all(root.join(dir)).unwrap();
            fs::write(root.join(dir).join("max_brightness"), format!("{max}\n")).unwrap();
        }
        assert_eq!(keyboard_light(&root), json!({ "device": "chromeos::kbd_backlight", "max": 100 }));
        assert_eq!(keyboard_light(&root.join("nothing")), Value::Null);
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn makes_the_directories_it_is_given() {
        let root = scratch("dirs");
        let private = root.join("run");
        let reply = hello(&json!({ "dirs": [root.join("a/b")], "privateDir": private, "link": root.join("missing") }));
        assert!(root.join("a/b").is_dir());
        assert_eq!(fs::metadata(&private).unwrap().permissions().mode() & 0o777, 0o700);
        assert_eq!(reply["wallpaperLink"], "");
        fs::remove_dir_all(root).unwrap();
    }
}
