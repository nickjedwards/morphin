//! morpher: one binary, two jobs for the morphin shell.
//!
//! As a command (`morpher its-morphin-time`, `morpher dinozord …`) it is
//! Quickshell pointed at the shell's QML: see `cli`.
//!
//! As `morpher alpha` it is the handful of things the shell would otherwise
//! poll or start a process for. The shell starts it once and talks to it
//! over stdin/stdout, one JSON object per line each way.
//!
//! In:
//!   {"cmd":"init","dirs":[…],"privateDir":"…","link":"…"}   → hello
//!   {"cmd":"procs","on":true,"sort":"cpu"|"mem"}            → procs, once a second
//!   {"cmd":"backlights"}                                    → backlights, then backlight on change
//!   {"cmd":"kbd"}                                           → kbd, now
//!   {"cmd":"brightness","subsystem":"backlight"|"leds","id":"…","value":123}
//!
//! Out:
//!   {"type":"hello", …}                 what `probe` found
//!   {"type":"procs","list":[…]}         the five busiest processes
//!   {"type":"backlights","list":[{"id":"…","connector":"eDP-1","level":123,"max":255}]}
//!   {"type":"backlight","id":"…","value":123}
//!   {"type":"kbd","value":2}            keyboard backlight, on change
//!
//! It exits when stdin closes, so it never outlives the shell.

mod cli;
mod light;
mod probe;
mod procs;

use std::io::{BufRead, Write};
use std::sync::mpsc::{self, RecvTimeoutError};
use std::thread;
use std::time::{Duration, Instant};

use serde_json::Value;

pub enum Event {
    Command(Value),
    /// A watched backlight said it changed.
    Backlight(String),
    Closed,
}

/// One line to the shell. A closed pipe means the shell is gone.
pub fn emit(message: Value) {
    let mut out = std::io::stdout().lock();
    if writeln!(out, "{message}").and_then(|_| out.flush()).is_err() {
        std::process::exit(0);
    }
}

const PROCS_EVERY: Duration = Duration::from_secs(1);
const KBD_EVERY: Duration = Duration::from_millis(250);

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.first().map(String::as_str) == Some("alpha") {
        alpha();
    } else {
        std::process::exit(cli::run(&args));
    }
}

fn alpha() {
    let (tx, rx) = mpsc::channel();

    let stdin_tx = tx.clone();
    thread::spawn(move || {
        for line in std::io::stdin().lock().lines() {
            let Ok(line) = line else { break };
            if let Ok(command) = serde_json::from_str(&line) {
                if stdin_tx.send(Event::Command(command)).is_err() {
                    return;
                }
            }
        }
        let _ = stdin_tx.send(Event::Closed);
    });

    let mut sampler = procs::Sampler::new();
    let mut backlights = light::Backlights::new(tx);
    let mut keyboard: Option<light::Keyboard> = None;
    let mut logind = light::Logind::default();

    let mut procs_due: Option<Instant> = None;
    let mut kbd_due: Option<Instant> = None;

    loop {
        let due = [procs_due, kbd_due].into_iter().flatten().min();
        let event = match due {
            None => rx.recv().ok(),
            Some(at) => match rx.recv_timeout(at.saturating_duration_since(Instant::now())) {
                Ok(event) => Some(event),
                Err(RecvTimeoutError::Timeout) => None,
                Err(RecvTimeoutError::Disconnected) => return,
            },
        };

        match event {
            Some(Event::Closed) => return,
            Some(Event::Backlight(id)) => backlights.changed(&id),
            Some(Event::Command(command)) => match command["cmd"].as_str() {
                Some("init") => {
                    let hello = probe::hello(&command);
                    keyboard = hello["kbd"]["device"].as_str().map(light::Keyboard::new);
                    emit(hello);
                    kbd_due = keyboard.as_ref().map(|_| Instant::now());
                }
                Some("procs") => {
                    let by_mem = command["sort"].as_str() == Some("mem");
                    if command["on"].as_bool().unwrap_or(false) {
                        if sampler.start(by_mem) {
                            procs_due = Some(Instant::now() + PROCS_EVERY);
                        }
                    } else {
                        sampler.stop();
                        procs_due = None;
                    }
                }
                Some("backlights") => emit(backlights.discover()),
                Some("kbd") => {
                    if let Some(keyboard) = keyboard.as_mut() {
                        keyboard.report();
                    }
                }
                Some("brightness") => {
                    if let (Some(subsystem), Some(id), Some(value)) = (
                        command["subsystem"].as_str(),
                        command["id"].as_str(),
                        command["value"].as_u64(),
                    ) {
                        match logind.set(subsystem, id, value as u32) {
                            Err(error) => eprintln!("morpher: brightness of {subsystem}/{id}: {error}"),
                            Ok(()) if subsystem == "backlight" => backlights.wrote(id, value),
                            Ok(()) => {
                                if let Some(keyboard) = keyboard.as_mut() {
                                    keyboard.wrote(id, value);
                                }
                            }
                        }
                    }
                }
                _ => {}
            },
            None => {}
        }

        let now = Instant::now();
        if procs_due.is_some_and(|at| at <= now) {
            sampler.tick();
            procs_due = Some(now + PROCS_EVERY);
        }
        if kbd_due.is_some_and(|at| at <= now) {
            if let Some(keyboard) = keyboard.as_mut() {
                keyboard.poll();
            }
            kbd_due = Some(now + KBD_EVERY);
        }
    }
}
