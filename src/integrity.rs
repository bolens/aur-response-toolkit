use crate::inspection::{self, Bounded};
use crate::ioc;
use crate::model::Campaign;
use serde::Deserialize;
use std::collections::BTreeMap;
use std::path::Path;

#[derive(Debug, Deserialize)]
pub struct Manifest {
    pub version: String,
    pub ioc_registry_sha256: String,
    pub lists: BTreeMap<String, String>,
}

pub fn load(path: &Path) -> Result<Manifest, String> {
    let input = match inspection::read_text(path)
        .map_err(|error| format!("{}: {error}", path.display()))?
    {
        Bounded::Value(input) => input,
        Bounded::Oversize => return Err(format!("{} exceeds inspection limit", path.display())),
    };
    toml::from_str(&input).map_err(|error| format!("{}: {error}", path.display()))
}

pub fn validate_registry(manifest: &Manifest) -> Result<(), String> {
    if manifest.version != ioc::IOC_REGISTRY_VERSION {
        return Err(format!(
            "integrity manifest version {} does not match IOC registry {}",
            manifest.version,
            ioc::IOC_REGISTRY_VERSION
        ));
    }
    let actual = ioc::registry_sha256();
    if manifest.ioc_registry_sha256 != actual {
        return Err("IOC registry integrity mismatch".into());
    }
    Ok(())
}

pub fn validate_list(manifest: &Manifest, campaign: Campaign, path: &Path) -> Result<(), String> {
    let expected = manifest
        .lists
        .get(campaign.slug())
        .ok_or_else(|| format!("integrity manifest lacks {} list", campaign.slug()))?;
    let actual = match inspection::sha256(path, inspection::MAX_ARTIFACT_BYTES)
        .map_err(|error| format!("{}: {error}", path.display()))?
    {
        Bounded::Value(hash) => hash,
        Bounded::Oversize => return Err(format!("{} exceeds integrity limit", path.display())),
    };
    if &actual != expected {
        return Err(format!("{} list integrity mismatch", campaign.slug()));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn bundled_manifest_matches_registry_and_lists() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let manifest = load(&root.join("data/integrity.toml")).unwrap();
        validate_registry(&manifest).unwrap();
        for campaign in Campaign::ALL {
            validate_list(
                &manifest,
                campaign,
                &root
                    .join("data/lists")
                    .join(format!("{}-pkgs.txt", campaign.slug())),
            )
            .unwrap();
        }
    }

    #[test]
    fn rejects_tampered_campaign_list() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let manifest = load(&root.join("data/integrity.toml")).unwrap();
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("atomic-arch-pkgs.txt");
        fs::write(&path, "unexpected-package\n").unwrap();
        assert!(validate_list(&manifest, Campaign::AtomicArch, &path)
            .unwrap_err()
            .contains("integrity mismatch"));
    }

    #[test]
    fn rejects_registry_version_and_hash_drift() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let mut manifest = load(&root.join("data/integrity.toml")).unwrap();
        manifest.version = "2026-08-23.9".into();
        assert!(validate_registry(&manifest)
            .unwrap_err()
            .contains("does not match IOC registry"));

        manifest.version = ioc::IOC_REGISTRY_VERSION.into();
        manifest.ioc_registry_sha256 = "0".repeat(64);
        assert_eq!(
            validate_registry(&manifest).unwrap_err(),
            "IOC registry integrity mismatch"
        );
    }

    #[test]
    fn rejects_missing_campaign_and_malformed_manifest() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let mut manifest = load(&root.join("data/integrity.toml")).unwrap();
        manifest.lists.remove(Campaign::XsnowWorm.slug());
        let list = root.join("data/lists/xsnow-worm-pkgs.txt");
        assert_eq!(
            validate_list(&manifest, Campaign::XsnowWorm, &list).unwrap_err(),
            "integrity manifest lacks xsnow-worm list"
        );

        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("integrity.toml");
        fs::write(&path, "version = [not valid").unwrap();
        assert!(load(&path).unwrap_err().contains("integrity.toml"));
    }

    #[test]
    fn rejects_oversized_manifest_without_parsing_it() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("integrity.toml");
        fs::write(&path, vec![b'x'; inspection::MAX_TEXT_BYTES as usize + 1]).unwrap();
        assert_eq!(
            load(&path).unwrap_err(),
            format!("{} exceeds inspection limit", path.display())
        );
    }
}
