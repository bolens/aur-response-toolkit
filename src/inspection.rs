use sha2::{Digest, Sha256};
use std::fs::{self, File};
use std::io::{self, Read};
use std::path::Path;

pub const MAX_TEXT_BYTES: u64 = 1_048_576;
pub const MAX_ARTIFACT_BYTES: u64 = 16_777_216;

#[derive(Debug, Eq, PartialEq)]
pub enum Bounded<T> {
    Value(T),
    Oversize,
}

pub fn read(path: &Path, limit: u64) -> io::Result<Bounded<Vec<u8>>> {
    if fs::metadata(path)?.len() > limit {
        return Ok(Bounded::Oversize);
    }
    let mut bytes = Vec::new();
    File::open(path)?.take(limit + 1).read_to_end(&mut bytes)?;
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
    if fs::metadata(path)?.len() > limit {
        return Ok(Bounded::Oversize);
    }
    let mut file = File::open(path)?;
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
}
