use crate::model::Campaign;
use flate2::read::GzDecoder;
use regex::Regex;
use std::collections::{BTreeMap, BTreeSet};
use std::ffi::OsStr;
use std::fs::{self, File};
use std::io::{self, BufRead, BufReader, Read};
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Event {
    pub package: String,
    pub line: String,
    pub date: String,
}

fn reader(path: &Path) -> io::Result<Box<dyn Read>> {
    let file = File::open(path)?;
    match path.extension().and_then(OsStr::to_str) {
        Some("gz") => Ok(Box::new(GzDecoder::new(file))),
        Some(ext @ ("xz" | "zst" | "bz2")) => {
            let program = match ext {
                "xz" => "xz",
                "zst" => "zstd",
                _ => "bzip2",
            };
            let output = Command::new(program).args(["-dc"]).arg(path).output()?;
            if output.status.success() {
                Ok(Box::new(io::Cursor::new(output.stdout)))
            } else {
                Err(io::Error::new(
                    io::ErrorKind::InvalidData,
                    format!("{program} failed"),
                ))
            }
        }
        _ => Ok(Box::new(file)),
    }
}

pub fn log_paths(dir: &Path) -> io::Result<Vec<PathBuf>> {
    let mut paths = Vec::new();
    for item in fs::read_dir(dir)? {
        let path = item?.path();
        if path
            .file_name()
            .and_then(OsStr::to_str)
            .is_some_and(|v| v.starts_with("pacman.log"))
        {
            paths.push(path);
        }
    }
    paths.sort();
    Ok(paths)
}

pub fn events(dir: &Path, campaign: Campaign, all_time: bool) -> io::Result<Vec<Event>> {
    events_with_window(dir, campaign, all_time, None)
}

pub fn events_with_window(
    dir: &Path,
    campaign: Campaign,
    all_time: bool,
    window_regex: Option<&str>,
) -> io::Result<Vec<Event>> {
    let action =
        Regex::new(r"\[ALPM\] (installed|upgraded|downgraded|reinstalled) ([^ ]+)").unwrap();
    let date_re = Regex::new(r"^\[(\d{4}-\d{2}-\d{2})").unwrap();
    let custom_window = window_regex
        .map(Regex::new)
        .transpose()
        .map_err(|error| io::Error::new(io::ErrorKind::InvalidInput, error))?;
    let (start, end, _) = campaign.window();
    let mut result = Vec::new();
    for path in log_paths(dir)? {
        let input = BufReader::new(reader(&path)?);
        for line in input.lines().map_while(Result::ok) {
            let Some(cap) = action.captures(&line) else {
                continue;
            };
            let date = date_re
                .captures(&line)
                .map(|c| c[1].to_owned())
                .unwrap_or_default();
            let in_window = custom_window
                .as_ref()
                .map(|pattern| pattern.is_match(&line))
                .unwrap_or_else(|| date.as_str() >= start && date.as_str() <= end);
            if all_time || in_window {
                result.push(Event {
                    package: cap[2].to_owned(),
                    line,
                    date,
                });
            }
        }
    }
    Ok(result)
}

pub fn foreign_packages() -> io::Result<BTreeSet<String>> {
    if let Some(path) = std::env::var_os("AUR_TEST_FOREIGN_LIST") {
        return package_lines(&fs::read_to_string(path)?);
    }
    let output = Command::new("pacman").arg("-Qqm").output()?;
    if !output.status.success() {
        return Err(io::Error::other("pacman -Qqm failed"));
    }
    package_lines(&String::from_utf8_lossy(&output.stdout))
}

fn package_lines(input: &str) -> io::Result<BTreeSet<String>> {
    Ok(input
        .lines()
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .map(str::to_owned)
        .collect())
}

pub fn installed_packages() -> io::Result<BTreeSet<String>> {
    if let Some(path) = std::env::var_os("AUR_TEST_FOREIGN_LIST") {
        return package_lines(&fs::read_to_string(path)?);
    }
    foreign_packages()
}

pub fn package_install_epochs(local_dir: &Path) -> io::Result<BTreeMap<String, i64>> {
    let mut result = BTreeMap::new();
    for entry in fs::read_dir(local_dir)? {
        let dir = entry?.path();
        let desc = dir.join("desc");
        let Ok(input) = fs::read_to_string(desc) else {
            continue;
        };
        let mut name = None;
        let mut epoch = None;
        let mut lines = input.lines();
        while let Some(line) = lines.next() {
            match line {
                "%NAME%" => name = lines.next().map(str::to_owned),
                "%INSTALLDATE%" => epoch = lines.next().and_then(|v| v.parse().ok()),
                _ => {}
            }
        }
        if let (Some(name), Some(epoch)) = (name, epoch) {
            result.insert(name, epoch);
        }
    }
    Ok(result)
}

pub fn timeline_hits(
    events: &[Event],
    packages: &BTreeSet<String>,
) -> BTreeMap<String, Vec<String>> {
    let mut hits = BTreeMap::<String, Vec<String>>::new();
    for event in events {
        if packages.contains(&event.package) {
            hits.entry(event.package.clone())
                .or_default()
                .push(event.line.clone());
        }
    }
    hits
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_install_and_upgrade_without_remove() {
        let re =
            Regex::new(r"\[ALPM\] (installed|upgraded|downgraded|reinstalled) ([^ ]+)").unwrap();
        assert_eq!(
            re.captures("[x] [ALPM] installed beef (1-1)").unwrap()[2].to_string(),
            "beef"
        );
        assert!(re.captures("[x] [ALPM] removed beef (1-1)").is_none());
    }
}
