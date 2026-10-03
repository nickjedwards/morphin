//! The command itself. Every command is a Quickshell one under another
//! name, pointed at the shell's QML wherever this binary was installed.

use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

/// Which Quickshell to run: `make QS=…` at build time, `qs` otherwise.
const QS: &str = match option_env!("MORPHIN_QS") {
    Some(qs) => qs,
    None => "qs",
};

/// What the shell is installed as (its folder under share/): `make NAME=…`
/// at build time, `morphin` otherwise.
const SHELL: &str = match option_env!("MORPHIN_NAME") {
    Some(name) => name,
    None => "morphin",
};

struct Spec {
    name: &'static str,
    args: &'static str,
    about: &'static str,
}

/// The commands, in the order help lists them. `alpha` (what the shell
/// starts for itself, see main.rs) is deliberately not among them.
const COMMANDS: [Spec; 8] = [
    Spec { name: "its-morphin-time", args: "[--stay]", about: "start the shell, detached (--stay keeps it in the foreground)" },
    Spec { name: "power-down", args: "", about: "stop it" },
    Spec { name: "back-to-action", args: "", about: "restart it" },
    Spec { name: "dinozord", args: "<target> <function> [arguments]", about: "call the running shell: morpher dinozord launcher toggle" },
    Spec { name: "morphing-grid", args: "", about: "list everything dinozord can call" },
    Spec { name: "viewing-globe", args: "[options]", about: "show the shell's log" },
    Spec { name: "roll-call", args: "[options]", about: "list running instances" },
    Spec { name: "qs", args: "[arguments]", about: "run Quickshell itself on this shell" },
];

/// Quickshell's own names for the same things, for anyone who types them.
const FORMERLY: [(&str, &str); 4] = [("ipc", "dinozord"), ("kill", "power-down"), ("list", "roll-call"), ("log", "viewing-globe")];

fn help() -> String {
    const COLUMN: usize = 28;
    let mut text = String::from("morpher: the morphin shell's command. It's morphin' time!\n\nUsage: morpher <command> [arguments]\n\n");
    for spec in &COMMANDS {
        let left = format!("{} {}", spec.name, spec.args);
        // A long one gets a line to itself, its description underneath.
        if left.trim_end().len() < COLUMN {
            text += &format!("  {left:<COLUMN$} {}\n", spec.about);
        } else {
            text += &format!("  {left}\n  {:COLUMN$} {}\n", "", spec.about);
        }
    }
    text += &format!("\n  {:<COLUMN$} this\n  {:<COLUMN$} the version\n", "help, --help", "--version");
    text
}

#[derive(Debug, PartialEq)]
enum Plan {
    Help,
    Version,
    /// Become Quickshell with these arguments.
    Exec(Vec<String>),
    /// Run Quickshell with the first, wait, then become it with the second.
    Then(Vec<String>, Vec<String>),
}

/// A command used wrongly: what to say about it.
#[derive(Debug, PartialEq)]
struct Usage(String);

fn strings(args: &[&str]) -> Vec<String> {
    args.iter().map(|s| s.to_string()).collect()
}

/// Quickshell's subcommands take the path after their name; anything else
/// is options for running the shell.
fn qs_args(dir: &str, args: &[String]) -> Vec<String> {
    match args.first() {
        Some(sub) if FORMERLY.iter().any(|(old, _)| old == sub) => [strings(&[sub, "-p", dir]), args[1..].to_vec()].concat(),
        _ => [strings(&["-p", dir]), args.to_vec()].concat(),
    }
}

/// What a command line comes to, for the shell in `dir`.
fn plan(dir: &str, args: &[String]) -> Result<Plan, Usage> {
    let Some((command, rest)) = args.split_first() else { return Ok(Plan::Help) };
    let alone = |plan: Plan| {
        if rest.is_empty() {
            Ok(plan)
        } else {
            Err(Usage(format!("`{command}` takes no arguments")))
        }
    };
    match command.as_str() {
        "help" | "-h" | "--help" => Ok(Plan::Help),
        "-V" | "--version" => Ok(Plan::Version),
        "its-morphin-time" => {
            let options: Vec<String> = rest.iter().filter(|a| *a != "--stay").cloned().collect();
            // -n: someone already morphed is not an error, and not twice.
            let how = if options.len() < rest.len() { strings(&["-p", dir]) } else { strings(&["-p", dir, "-d", "-n"]) };
            Ok(Plan::Exec([how, options].concat()))
        }
        "power-down" => alone(Plan::Exec(strings(&["kill", "-p", dir]))),
        // No -n: the one just told to stop may not have gone yet.
        "back-to-action" => alone(Plan::Then(strings(&["kill", "-p", dir]), strings(&["-p", dir, "-d"]))),
        "dinozord" if rest.len() < 2 => {
            Err(Usage("`dinozord` needs a target and a function; `morpher morphing-grid` lists them".into()))
        }
        "dinozord" => Ok(Plan::Exec([strings(&["ipc", "-p", dir, "call"]), rest.to_vec()].concat())),
        "morphing-grid" => alone(Plan::Exec(strings(&["ipc", "-p", dir, "show"]))),
        "viewing-globe" => Ok(Plan::Exec([strings(&["log", "-p", dir]), rest.to_vec()].concat())),
        "roll-call" => Ok(Plan::Exec([strings(&["list", "-p", dir]), rest.to_vec()].concat())),
        "qs" => Ok(Plan::Exec(qs_args(dir, rest))),
        unknown => Err(Usage(match suggest(unknown) {
            Some(name) => format!("no command `{unknown}`; did you mean `{name}`?"),
            None => format!("no command `{unknown}`"),
        })),
    }
}

/// The command someone most likely meant: Quickshell's name for it, the
/// start of one, or a near miss.
fn suggest(typed: &str) -> Option<&'static str> {
    if let Some((_, now)) = FORMERLY.iter().find(|(old, _)| *old == typed) {
        return Some(now);
    }
    if let Some(spec) = COMMANDS.iter().find(|spec| typed.len() > 1 && spec.name.starts_with(typed)) {
        return Some(spec.name);
    }
    COMMANDS
        .iter()
        .map(|spec| (distance(typed, spec.name), spec.name))
        .filter(|(distance, name)| *distance <= name.len() / 3)
        .min()
        .map(|(_, name)| name)
}

/// Edits (insert, delete, replace) between two words.
fn distance(a: &str, b: &str) -> usize {
    let b: Vec<char> = b.chars().collect();
    let mut row: Vec<usize> = (0..=b.len()).collect();
    for (i, ca) in a.chars().enumerate() {
        let mut diagonal = row[0];
        row[0] = i + 1;
        for (j, cb) in b.iter().enumerate() {
            let replaced = diagonal + usize::from(ca != *cb);
            diagonal = row[j + 1];
            row[j + 1] = replaced.min(row[j] + 1).min(row[j + 1] + 1);
        }
    }
    row[b.len()]
}

/// The QML for a binary at `exe`: $MORPHIN_SHELL_DIR if that's set, else
/// <prefix>/share/<shell> beside an installed <prefix>/bin/morpher, or
/// quickshell/ in the checkout cargo built it in
/// (morpher/target/<profile>/morpher).
fn shell_dir(exe: &Path, shell: &str, chosen: Option<PathBuf>) -> Option<PathBuf> {
    let installed = exe.parent().and_then(Path::parent).map(|prefix| prefix.join("share").join(shell));
    let checkout = exe.ancestors().nth(4).map(|root| root.join("quickshell"));
    [chosen, installed, checkout].into_iter().flatten().find(|dir| dir.join("shell.qml").is_file())
}

/// Carries a command out; returns (as an exit code) unless it became
/// Quickshell.
pub fn run(args: &[String]) -> i32 {
    // The real file, links followed: that's the one with share/ beside it.
    let exe = std::env::current_exe().and_then(std::fs::canonicalize).unwrap_or_default();
    let dir = shell_dir(&exe, SHELL, std::env::var_os("MORPHIN_SHELL_DIR").map(PathBuf::from));

    let found = dir.as_deref().map(|dir| dir.to_string_lossy().into_owned()).unwrap_or_default();
    let (first, last) = match plan(&found, args) {
        Ok(Plan::Help) => {
            print!("{}", help());
            return 0;
        }
        Ok(Plan::Version) => {
            println!("morpher {}", env!("CARGO_PKG_VERSION"));
            return 0;
        }
        Ok(Plan::Exec(last)) => (None, last),
        Ok(Plan::Then(first, last)) => (Some(first), last),
        Err(Usage(message)) => {
            eprintln!("morpher: {message}\nTry `morpher help`.");
            return 2;
        }
    };
    if dir.is_none() {
        eprintln!("morpher: can't find the shell's files (expected ../share/{SHELL} beside {})", exe.display());
        return 1;
    }
    if let Some(first) = first {
        // Quietly: with nothing running there is nothing to stop, and that's fine.
        let _ = Command::new(QS).args(first).stdout(Stdio::null()).stderr(Stdio::null()).status();
    }
    let error = Command::new(QS).args(last).exec();
    eprintln!("morpher: can't run {QS}: {error}");
    127
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    const DIR: &str = "/usr/share/morphin";

    fn exec(args: &[&str]) -> Result<Plan, Usage> {
        Ok(Plan::Exec(strings(args)))
    }

    fn planned(args: &[&str]) -> Result<Plan, Usage> {
        plan(DIR, &strings(args))
    }

    #[test]
    fn every_command_is_a_quickshell_one() {
        assert_eq!(planned(&["its-morphin-time"]), exec(&["-p", DIR, "-d", "-n"]));
        assert_eq!(planned(&["its-morphin-time", "--stay"]), exec(&["-p", DIR]));
        assert_eq!(planned(&["its-morphin-time", "--stay", "-v"]), exec(&["-p", DIR, "-v"]));
        assert_eq!(planned(&["power-down"]), exec(&["kill", "-p", DIR]));
        assert_eq!(planned(&["back-to-action"]), Ok(Plan::Then(strings(&["kill", "-p", DIR]), strings(&["-p", DIR, "-d"]))));
        assert_eq!(planned(&["dinozord", "wallpaper", "set", "a b.png"]), exec(&["ipc", "-p", DIR, "call", "wallpaper", "set", "a b.png"]));
        assert_eq!(planned(&["morphing-grid"]), exec(&["ipc", "-p", DIR, "show"]));
        assert_eq!(planned(&["viewing-globe", "-f"]), exec(&["log", "-p", DIR, "-f"]));
        assert_eq!(planned(&["roll-call", "--all"]), exec(&["list", "-p", DIR, "--all"]));
    }

    #[test]
    fn qs_is_quickshell_as_it_comes() {
        assert_eq!(planned(&["qs", "ipc", "call", "launcher", "toggle"]), exec(&["ipc", "-p", DIR, "call", "launcher", "toggle"]));
        assert_eq!(planned(&["qs", "-d", "-n"]), exec(&["-p", DIR, "-d", "-n"]));
        assert_eq!(planned(&["qs"]), exec(&["-p", DIR]));
    }

    #[test]
    fn help_and_version() {
        assert_eq!(planned(&[]), Ok(Plan::Help));
        for flag in ["help", "-h", "--help"] {
            assert_eq!(planned(&[flag]), Ok(Plan::Help));
        }
        assert_eq!(planned(&["--version"]), Ok(Plan::Version));
        for spec in &COMMANDS {
            assert!(help().contains(spec.name));
        }
        assert!(!help().contains("alpha"));
    }

    #[test]
    fn says_what_was_wrong() {
        let message = |args: &[&str]| planned(args).unwrap_err().0;
        assert!(message(&["dinozord", "launcher"]).contains("morphing-grid"));
        assert!(message(&["power-down", "now"]).contains("takes no arguments"));
        assert!(message(&["power-dwon"]).contains("did you mean `power-down`?"));
        assert!(message(&["dino"]).contains("did you mean `dinozord`?"));
        assert!(message(&["kill"]).contains("did you mean `power-down`?"));
        assert_eq!(message(&["serve"]), "no command `serve`");
        assert_eq!(message(&["-d"]), "no command `-d`");
    }

    #[test]
    fn counts_edits() {
        assert_eq!(distance("roll-call", "roll-call"), 0);
        assert_eq!(distance("rol-call", "roll-call"), 1);
        assert_eq!(distance("dinozrod", "dinozord"), 2);
        assert_eq!(distance("", "qs"), 2);
    }

    #[test]
    fn finds_the_shell_installed_or_in_a_checkout() {
        let root = std::env::temp_dir().join(format!("morphin-cli-{}", std::process::id()));
        let _ = fs::remove_dir_all(&root);
        for dir in ["usr/share/other", "repo/quickshell"] {
            fs::create_dir_all(root.join(dir)).unwrap();
            fs::write(root.join(dir).join("shell.qml"), "").unwrap();
        }
        assert_eq!(shell_dir(&root.join("usr/bin/morpher"), "other", None), Some(root.join("usr/share/other")));
        assert_eq!(shell_dir(&root.join("usr/bin/morpher"), "morphin", None), None);
        assert_eq!(shell_dir(&root.join("repo/morpher/target/release/morpher"), "morphin", None), Some(root.join("repo/quickshell")));
        assert_eq!(shell_dir(&root.join("elsewhere/bin/morpher"), "morphin", Some(root.join("repo/quickshell"))), Some(root.join("repo/quickshell")));
        fs::remove_dir_all(root).unwrap();
    }
}
