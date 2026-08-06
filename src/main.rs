use aur_response::cli::{self, CommandKind};
use aur_response::config;
use aur_response::engine::Engine;
use aur_response::EXIT_INVALID;
use std::env;
use std::path::PathBuf;

fn main() {
    let mut args = env::args().collect::<Vec<_>>();
    let argv0 = args.remove(0);
    let parsed = match cli::parse(&argv0, &args) {
        Ok(parsed) => parsed,
        Err((code, message)) => {
            if code == EXIT_INVALID {
                eprint!("{message}")
            } else {
                print!("{message}")
            }
            std::process::exit(code);
        }
    };
    if parsed.kind == CommandKind::ConfigMigrate {
        let dir = config::config_dir();
        let source = parsed
            .positionals
            .first()
            .map(PathBuf::from)
            .unwrap_or_else(|| dir.join("config.fish"));
        let destination = parsed
            .positionals
            .get(1)
            .map(PathBuf::from)
            .unwrap_or_else(|| dir.join("config.toml"));
        match config::migrate(&source, &destination) {
            Ok(_) => {
                println!("Migrated {} to {}", source.display(), destination.display());
                return;
            }
            Err(e) => {
                eprintln!("configuration migration failed:\n{e}");
                std::process::exit(EXIT_INVALID);
            }
        }
    }
    let loaded = match config::load() {
        Ok(v) => v,
        Err(e) => {
            eprintln!("configuration error: {e}");
            std::process::exit(EXIT_INVALID);
        }
    };
    let mut engine = Engine::new(loaded.config);
    std::process::exit(engine.execute(&parsed));
}
