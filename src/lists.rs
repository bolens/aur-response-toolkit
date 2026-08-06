use regex::Regex;
use std::collections::BTreeSet;

fn valid_package(value: &str) -> bool {
    Regex::new(r"^[a-z0-9][a-z0-9_.+\-]*[a-z0-9]$")
        .unwrap()
        .is_match(value)
}

pub fn plain(input: &str) -> BTreeSet<String> {
    input
        .lines()
        .map(str::trim)
        .filter(|value| valid_package(value))
        .map(str::to_owned)
        .collect()
}

pub fn html_lines(input: &str) -> BTreeSet<String> {
    let tags = Regex::new(r"<[^>]*>").unwrap();
    plain(&tags.replace_all(input, ""))
}

pub fn cscs_script(input: &str) -> BTreeSet<String> {
    let mut in_block = false;
    let mut packages = BTreeSet::new();
    for line in input.lines().map(str::trim) {
        if line.starts_with("INFECTED_PKGS=(") {
            in_block = true;
            continue;
        }
        if in_block && line == ")" {
            break;
        }
        if in_block && valid_package(line) {
            packages.insert(line.to_owned());
        }
    }
    packages
}

pub fn chaos_advisory(input: &str) -> BTreeSet<String> {
    let tags = Regex::new(r"<[^>]*>").unwrap();
    let text = tags.replace_all(input, " ");
    text.replace(',', "\n")
        .replace(" and ", "\n")
        .replace(" - ", "\n")
        .lines()
        .map(str::trim)
        .filter(|value| valid_package(value))
        .map(str::to_owned)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parsers_reject_markup_and_shell_noise() {
        assert_eq!(
            html_lines("<p>beef</p>\n<script>bad()</script>"),
            BTreeSet::from(["beef".to_owned()])
        );
        assert_eq!(
            cscs_script("x\nINFECTED_PKGS=(\nbeef\ninvalid name\n)\nafter"),
            BTreeSet::from(["beef".to_owned()])
        );
        assert!(chaos_advisory("<p>affected: - beef - known-bad</p>").contains("beef"));
    }
}
