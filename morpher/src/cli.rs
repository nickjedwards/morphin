//! The command itself: Quickshell pointed at the shell's QML, wherever this
//! binary was installed.

use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::Command;

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

const SUBCOMMANDS: [&str; 4] = ["ipc", "kill", "list", "log"];

fn usage(name: &str) -> String {
    format!(
        "{name}: Quickshell pointed at the installed shell.

  {name}                           run it in the foreground
  {name} -d                        detach (add -n to do nothing if it's already running)
  {name} ipc call launcher toggle  talk to the running one
  {name} ipc show                  list everything it answers to
  {name} kill | list | log         ditto
"
    )
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

/// What to hand Quickshell: its own subcommands go first, with the rest
/// after the path; anything else is options for running the shell.
fn qs_args(dir: &Path, args: &[String]) -> Vec<String> {
    let dir = dir.to_string_lossy().into_owned();
    match args.first() {
        Some(sub) if SUBCOMMANDS.contains(&sub.as_str()) => {
            [vec![sub.clone(), "-p".into(), dir], args[1..].to_vec()].concat()
        }
        _ => [vec!["-p".into(), dir], args.to_vec()].concat(),
    }
}

/// Becomes Quickshell; only returns (as an exit code) when it can't.
pub fn run(args: &[String]) -> i32 {
    // The real file, links followed: that's the one with share/ beside it.
    let exe = std::env::current_exe().and_then(std::fs::canonicalize).unwrap_or_default();
    let name = exe.file_name().and_then(|n| n.to_str()).unwrap_or("morpher").to_string();

    if matches!(args.first().map(String::as_str), Some("-h" | "--help")) {
        print!("{}", usage(&name));
        return 0;
    }
    let chosen = std::env::var_os("MORPHIN_SHELL_DIR").map(PathBuf::from);
    let Some(dir) = shell_dir(&exe, SHELL, chosen) else {
        eprintln!("{name}: can't find the shell's files (expected ../share/{SHELL} beside {})", exe.display());
        return 1;
    };
    let error = Command::new(QS).args(qs_args(&dir, args)).exec();
    eprintln!("{name}: can't run {QS}: {error}");
    127
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    fn strings(args: &[&str]) -> Vec<String> {
        args.iter().map(|s| s.to_string()).collect()
    }

    #[test]
    fn subcommands_go_before_the_path() {
        let dir = Path::new("/usr/share/morphin");
        assert_eq!(qs_args(dir, &strings(&["ipc", "call", "launcher", "toggle"])), ["ipc", "-p", "/usr/share/morphin", "call", "launcher", "toggle"]);
        assert_eq!(qs_args(dir, &strings(&["kill"])), ["kill", "-p", "/usr/share/morphin"]);
        assert_eq!(qs_args(dir, &strings(&["-d", "-n"])), ["-p", "/usr/share/morphin", "-d", "-n"]);
        assert_eq!(qs_args(dir, &[]), ["-p", "/usr/share/morphin"]);
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
