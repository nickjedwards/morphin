//! The busiest processes, read straight from /proc: each sample is compared
//! with the one before, so there's a fresh answer every second without
//! starting `top` for it.

use std::collections::HashMap;
use std::fs;

use serde_json::{json, Value};

const SHOWN: usize = 5;

#[derive(Clone, Debug, PartialEq)]
struct Proc {
    pid: u32,
    name: String,
    /// Percent of one core, like top: a process using two cores reads 200.
    cpu: f64,
    /// Percent of all memory.
    mem: f64,
}

pub struct Sampler {
    running: bool,
    by_mem: bool,
    /// CPU ticks each process had used at the last sample.
    ticks: HashMap<u32, u64>,
    total: u64,
    latest: Vec<Proc>,
    page_kb: u64,
}

impl Sampler {
    pub fn new() -> Self {
        // SAFETY: sysconf has no preconditions.
        let page = unsafe { libc::sysconf(libc::_SC_PAGESIZE) };
        Self {
            running: false,
            by_mem: false,
            ticks: HashMap::new(),
            total: 0,
            latest: Vec::new(),
            page_kb: if page > 0 { page as u64 / 1024 } else { 4 },
        }
    }

    /// Start sampling, or change the order. True when it was stopped: the
    /// first numbers come a sample later, since use is a difference.
    pub fn start(&mut self, by_mem: bool) -> bool {
        let resorted = self.by_mem != by_mem;
        self.by_mem = by_mem;
        if !self.running {
            self.running = true;
            self.sample();
            return true;
        }
        if resorted && !self.latest.is_empty() {
            self.emit();
        }
        false
    }

    pub fn stop(&mut self) {
        self.running = false;
        self.ticks.clear();
        self.latest.clear();
    }

    pub fn tick(&mut self) {
        if self.running {
            self.sample();
            self.emit();
        }
    }

    fn sample(&mut self) {
        let stat = fs::read_to_string("/proc/stat").unwrap_or_default();
        let (total, cores) = parse_total(&stat);
        let mem_total = fs::read_to_string("/proc/meminfo").ok().and_then(|s| parse_mem_total(&s)).unwrap_or(0);
        let elapsed = total.saturating_sub(self.total);

        let mut ticks = HashMap::with_capacity(self.ticks.len());
        let mut latest = Vec::with_capacity(self.ticks.len());
        for entry in fs::read_dir("/proc").into_iter().flatten().flatten() {
            let Some(pid) = entry.file_name().to_str().and_then(|n| n.parse::<u32>().ok()) else { continue };
            // A process can exit between being listed and being read.
            let Ok(stat) = fs::read_to_string(entry.path().join("stat")) else { continue };
            let Some((name, used, rss)) = parse_pid_stat(&stat) else { continue };
            ticks.insert(pid, used);
            // Only a process seen last time has a difference to show.
            let Some(&before) = self.ticks.get(&pid) else { continue };
            let cpu = if elapsed > 0 { used.saturating_sub(before) as f64 / elapsed as f64 * cores as f64 * 100.0 } else { 0.0 };
            let mem = if mem_total > 0 { (rss * self.page_kb) as f64 / mem_total as f64 * 100.0 } else { 0.0 };
            latest.push(Proc { pid, name: name.to_string(), cpu, mem });
        }
        self.ticks = ticks;
        self.total = total;
        self.latest = latest;
    }

    fn emit(&self) {
        crate::emit(json!({ "type": "procs", "list": top(&self.latest, self.by_mem) }));
    }
}

fn top(procs: &[Proc], by_mem: bool) -> Vec<Value> {
    let mut sorted: Vec<&Proc> = procs.iter().collect();
    let key = |p: &Proc| if by_mem { (p.mem, p.cpu) } else { (p.cpu, p.mem) };
    sorted.sort_by(|a, b| key(b).partial_cmp(&key(a)).unwrap_or(std::cmp::Ordering::Equal));
    sorted
        .into_iter()
        .take(SHOWN)
        .map(|p| json!({ "pid": p.pid, "name": p.name, "cpu": (p.cpu * 10.0).round() / 10.0, "mem": (p.mem * 10.0).round() / 10.0 }))
        .collect()
}

/// /proc/stat: all ticks since boot across every core, and how many cores.
fn parse_total(stat: &str) -> (u64, usize) {
    let mut total = 0;
    let mut cores = 0;
    for line in stat.lines().take_while(|l| l.starts_with("cpu")) {
        let mut fields = line.split_ascii_whitespace();
        if fields.next() == Some("cpu") {
            // user nice system idle iowait irq softirq steal; guest time is
            // already counted in user.
            total = fields.take(8).filter_map(|f| f.parse::<u64>().ok()).sum();
        } else {
            cores += 1;
        }
    }
    (total, cores.max(1))
}

fn parse_mem_total(meminfo: &str) -> Option<u64> {
    meminfo.lines().find_map(|l| l.strip_prefix("MemTotal:"))?.split_ascii_whitespace().next()?.parse().ok()
}

/// /proc/<pid>/stat: the name (in brackets, and free to contain spaces and
/// brackets of its own), ticks used (utime + stime) and resident pages.
fn parse_pid_stat(stat: &str) -> Option<(&str, u64, u64)> {
    let open = stat.find('(')?;
    let close = stat.rfind(')')?;
    let name = stat.get(open + 1..close)?;
    // After the name the fields count from 3 (state): utime is 14, stime 15,
    // rss 24.
    let fields: Vec<&str> = stat.get(close + 1..)?.split_ascii_whitespace().collect();
    let field = |n: usize| fields.get(n - 3)?.parse::<u64>().ok();
    Some((name, field(14)? + field(15)?, field(24)?))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_a_process_whose_name_has_spaces_and_brackets() {
        let stat = "4242 (Isolated Web) Co) S 1 4242 4242 0 -1 4194560 100 0 0 0 250 50 0 0 20 0 30 0 1000 123456789 2048 18446744073709551615 1 1 0 0 0 0 0 0 0 0 0 0 17 3 0 0 0 0 0";
        assert_eq!(parse_pid_stat(stat), Some(("Isolated Web) Co", 300, 2048)));
        assert_eq!(parse_pid_stat("garbage"), None);
    }

    #[test]
    fn totals_ticks_and_counts_cores() {
        let stat = "cpu  100 0 50 800 10 5 5 30 7 0\ncpu0 50 0 25 400 5 2 3 15 0 0\ncpu1 50 0 25 400 5 3 2 15 0 0\nintr 12345\n";
        assert_eq!(parse_total(stat), (1000, 2));
    }

    #[test]
    fn reads_total_memory() {
        assert_eq!(parse_mem_total("MemTotal:       32000000 kB\nMemFree:  1 kB\n"), Some(32000000));
    }

    #[test]
    fn orders_by_what_was_asked() {
        let procs = [
            Proc { pid: 1, name: "busy".into(), cpu: 150.04, mem: 1.0 },
            Proc { pid: 2, name: "big".into(), cpu: 2.0, mem: 40.0 },
        ];
        assert_eq!(top(&procs, false)[0], json!({ "pid": 1, "name": "busy", "cpu": 150.0, "mem": 1.0 }));
        assert_eq!(top(&procs, true)[0]["name"], "big");
    }
}
