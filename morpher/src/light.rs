//! Brightness: the screen backlight, which says when it changes, the
//! keyboard backlight, which doesn't, and writing either through logind.

use std::collections::{BTreeSet, HashMap};
use std::fs::{self, File};
use std::io::{Read, Seek, SeekFrom};
use std::os::fd::AsRawFd;
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc::Sender;
use std::sync::Arc;
use std::thread;

use serde_json::{json, Value};

use crate::Event;

fn read_level(path: &str) -> Option<u64> {
    fs::read_to_string(path).ok()?.trim().parse().ok()
}

/// A backlight device and the monitor it lights.
#[derive(Debug, PartialEq)]
struct Found {
    id: String,
    connector: String,
    level: u64,
    max: u64,
}

/// Every backlight under `root` (/sys/class/backlight). Its `device` link
/// leads to the DRM connector it belongs to, named like "card1-eDP-1";
/// Hyprland calls that monitor "eDP-1".
fn find(root: &Path) -> Vec<Found> {
    let mut found: Vec<Found> = fs::read_dir(root)
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|entry| {
            let dir = entry.path();
            let device = fs::canonicalize(dir.join("device")).ok()?;
            let connector = device.file_name()?.to_str()?;
            let connector = connector
                .strip_prefix("card")
                .map(|rest| rest.trim_start_matches(|c: char| c.is_ascii_digit()))
                .and_then(|rest| rest.strip_prefix('-'))
                .unwrap_or(connector);
            let read = |file: &str| fs::read_to_string(dir.join(file)).ok()?.trim().parse::<u64>().ok();
            let max = read("max_brightness").filter(|&max| max > 0)?;
            Some(Found { id: entry.file_name().to_str()?.to_string(), connector: connector.to_string(), level: read("brightness")?, max })
        })
        .collect();
    found.sort_by(|a, b| a.id.cmp(&b.id));
    found
}

/// Screen backlights. The kernel notifies `actual_brightness` whenever the
/// level is set — by us, by a brightness key, by anything else — so one
/// thread per backlight sleeps in poll() until then; nothing is re-read on
/// a timer.
pub struct Backlights {
    tx: Sender<Event>,
    watched: BTreeSet<String>,
    /// Bumped whenever the watched set changes; a waiter from an older set
    /// stops the next time it wakes.
    generation: Arc<AtomicU64>,
    levels: HashMap<String, u64>,
}

impl Backlights {
    pub fn new(tx: Sender<Event>) -> Self {
        Self { tx, watched: BTreeSet::new(), generation: Arc::new(AtomicU64::new(0)), levels: HashMap::new() }
    }

    /// Which backlights there are, on which monitors and how bright; from
    /// here on each one is watched for changes.
    pub fn discover(&mut self) -> Value {
        let found = find(Path::new("/sys/class/backlight"));
        self.watch(found.iter().map(|f| f.id.clone()).collect());
        self.levels = found.iter().map(|f| (f.id.clone(), f.level)).collect();
        let list: Vec<Value> = found
            .iter()
            .map(|f| json!({ "id": f.id, "connector": f.connector, "level": f.level, "max": f.max }))
            .collect();
        json!({ "type": "backlights", "list": list })
    }

    fn watch(&mut self, ids: BTreeSet<String>) {
        if ids == self.watched {
            return;
        }
        let generation = self.generation.fetch_add(1, Ordering::SeqCst) + 1;
        for id in &ids {
            let (id, tx, current) = (id.clone(), self.tx.clone(), self.generation.clone());
            thread::spawn(move || wait_for_changes(&id, generation, &current, &tx));
        }
        self.watched = ids;
    }

    /// The shell set it itself: that isn't news to report back.
    pub fn wrote(&mut self, id: &str, value: u64) {
        if self.watched.contains(id) {
            self.levels.insert(id.to_string(), value);
        }
    }

    /// A waiter woke: tell the shell, if the level really is different.
    pub fn changed(&mut self, id: &str) {
        if !self.watched.contains(id) {
            return;
        }
        let Some(value) = read_level(&format!("/sys/class/backlight/{id}/brightness")) else { return };
        if self.levels.insert(id.to_string(), value) != Some(value) {
            crate::emit(json!({ "type": "backlight", "id": id, "value": value }));
        }
    }
}

fn wait_for_changes(id: &str, generation: u64, current: &AtomicU64, tx: &Sender<Event>) {
    let Ok(mut file) = File::open(format!("/sys/class/backlight/{id}/actual_brightness")) else { return };
    let mut scratch = [0u8; 32];
    loop {
        // A sysfs file only reports changes made after it was last read.
        if file.seek(SeekFrom::Start(0)).is_err() || file.read(&mut scratch).is_err() {
            return;
        }
        if current.load(Ordering::SeqCst) != generation || tx.send(Event::Backlight(id.to_string())).is_err() {
            return;
        }
        let mut fds = [libc::pollfd { fd: file.as_raw_fd(), events: libc::POLLPRI | libc::POLLERR, revents: 0 }];
        // SAFETY: `fds` is one valid pollfd, and `file` outlives the call.
        let ready = unsafe { libc::poll(fds.as_mut_ptr(), 1, -1) };
        if ready < 0 && std::io::Error::last_os_error().kind() != std::io::ErrorKind::Interrupted {
            return;
        }
    }
}

/// The keyboard backlight. Firmware keys change it without telling anyone
/// (few LEDs have brightness_hw_changed), so it is re-read on a timer —
/// here rather than in the shell, which only hears when it changes.
pub struct Keyboard {
    device: String,
    path: String,
    level: Option<u64>,
}

impl Keyboard {
    pub fn new(device: &str) -> Self {
        Self { device: device.to_string(), path: format!("/sys/class/leds/{device}/brightness"), level: None }
    }

    pub fn poll(&mut self) {
        let level = read_level(&self.path);
        if level.is_some() && level != self.level {
            self.level = level;
            crate::emit(json!({ "type": "kbd", "value": level }));
        }
    }

    /// Say where it is now, changed or not.
    pub fn report(&mut self) {
        self.level = None;
        self.poll();
    }

    /// The shell set it itself: that isn't news to report back.
    pub fn wrote(&mut self, device: &str, value: u64) {
        if device == self.device {
            self.level = Some(value);
        }
    }
}

/// Writing brightness. The sysfs files are root's; logind writes them for
/// whoever owns the session, which is what brightnessctl asks it to do too.
#[derive(Default)]
pub struct Logind {
    connection: Option<zbus::blocking::Connection>,
}

impl Logind {
    pub fn set(&mut self, subsystem: &str, name: &str, value: u32) -> zbus::Result<()> {
        let connection = match self.connection.take() {
            Some(connection) => connection,
            None => zbus::blocking::Connection::system()?,
        };
        // A failed call drops the connection, so the next one starts afresh.
        connection.call_method(
            Some("org.freedesktop.login1"),
            "/org/freedesktop/login1/session/auto",
            Some("org.freedesktop.login1.Session"),
            "SetBrightness",
            &(subsystem, name, value),
        )?;
        self.connection = Some(connection);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn finds_backlights_and_their_monitors() {
        let root = std::env::temp_dir().join(format!("morphin-light-{}", std::process::id()));
        let _ = fs::remove_dir_all(&root);
        let backlight = root.join("backlight");
        for (id, connector, level, max) in [("amdgpu_bl1", "card1-eDP-1", "300", "65535"), ("dead", "card0-DP-2", "0", "0")] {
            fs::create_dir_all(root.join("drm").join(connector)).unwrap();
            fs::create_dir_all(backlight.join(id)).unwrap();
            std::os::unix::fs::symlink(root.join("drm").join(connector), backlight.join(id).join("device")).unwrap();
            fs::write(backlight.join(id).join("brightness"), format!("{level}\n")).unwrap();
            fs::write(backlight.join(id).join("max_brightness"), format!("{max}\n")).unwrap();
        }
        // No levels at all: skipped, like the one that can't be lit.
        fs::create_dir_all(backlight.join("empty")).unwrap();

        assert_eq!(find(&backlight), [Found { id: "amdgpu_bl1".into(), connector: "eDP-1".into(), level: 300, max: 65535 }]);
        assert_eq!(find(&root.join("nothing")), []);
        fs::remove_dir_all(root).unwrap();
    }
}
