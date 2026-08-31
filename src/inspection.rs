use sha2::{Digest, Sha256};
use std::fs::{File, OpenOptions};
use std::io::{self, Read};
use std::path::Path;

#[cfg(target_os = "linux")]
use std::os::unix::fs::OpenOptionsExt;

#[cfg(target_os = "linux")]
const O_NOFOLLOW: i32 = 0x20_000;

pub const MAX_TEXT_BYTES: u64 = 1_048_576;
pub const MAX_ARTIFACT_BYTES: u64 = 16_777_216;

#[derive(Debug, Eq, PartialEq)]
pub enum Bounded<T> {
    Value(T),
    Oversize,
}

fn open_readonly(path: &Path) -> io::Result<File> {
    let mut options = OpenOptions::new();
    options.read(true);
    #[cfg(target_os = "linux")]
    options.custom_flags(O_NOFOLLOW);
    options.open(path)
}

pub fn read(path: &Path, limit: u64) -> io::Result<Bounded<Vec<u8>>> {
    let file = open_readonly(path)?;
    if file.metadata()?.len() > limit {
        return Ok(Bounded::Oversize);
    }
    let mut bytes = Vec::new();
    file.take(limit + 1).read_to_end(&mut bytes)?;
    if bytes.len() as u64 > limit {
        Ok(Bounded::Oversize)
    } else {
        Ok(Bounded::Value(bytes))
    }
}

pub fn read_text(path: &Path) -> io::Result<Bounded<String>> {
    match read(path, MAX_TEXT_BYTES)? {
        Bounded::Value(bytes) => String::from_utf8(bytes)
            .map(Bounded::Value)
            .map_err(|error| io::Error::new(io::ErrorKind::InvalidData, error)),
        Bounded::Oversize => Ok(Bounded::Oversize),
    }
}

pub fn sha256(path: &Path, limit: u64) -> io::Result<Bounded<String>> {
    let mut file = open_readonly(path)?;
    if file.metadata()?.len() > limit {
        return Ok(Bounded::Oversize);
    }
    let mut digest = Sha256::new();
    let mut total = 0_u64;
    let mut buffer = [0_u8; 64 * 1024];
    loop {
        let read = file.read(&mut buffer)?;
        if read == 0 {
            break;
        }
        total += read as u64;
        if total > limit {
            return Ok(Bounded::Oversize);
        }
        digest.update(&buffer[..read]);
    }
    Ok(Bounded::Value(format!("{:x}", digest.finalize())))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn bounds_reads_and_streamed_hashes() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("sample");
        fs::write(&path, b"abcdef").unwrap();
        assert_eq!(read(&path, 5).unwrap(), Bounded::Oversize);
        assert!(matches!(read(&path, 6).unwrap(), Bounded::Value(_)));
        assert_eq!(sha256(&path, 5).unwrap(), Bounded::Oversize);
        assert_eq!(
            sha256(&path, 6).unwrap(),
            Bounded::Value(
                "bef57ec7f53a6d40beb640a780a639c83bc29ac8a9816f1fc6c5c6dcd93c4721".into()
            )
        );
    }

    #[cfg(target_os = "linux")]
    #[test]
    fn rejects_symlinks_before_reading_or_hashing_their_targets() {
        use std::os::unix::fs::symlink;

        let dir = tempfile::tempdir().unwrap();
        let target = dir.path().join("target");
        let link = dir.path().join("link");
        fs::write(&target, b"hostile target").unwrap();
        symlink(&target, &link).unwrap();

        assert!(read(&link, MAX_TEXT_BYTES).is_err());
        assert!(sha256(&link, MAX_ARTIFACT_BYTES).is_err());
    }
}
