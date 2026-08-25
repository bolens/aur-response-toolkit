pub mod alpm;
pub mod cli;
pub mod config;
pub mod engine;
pub mod inspection;
pub mod integrity;
pub mod ioc;
pub mod lists;
pub mod model;
pub mod report;

pub const VERSION: &str = env!("CARGO_PKG_VERSION");
pub const EXIT_CLEAN: i32 = 0;
pub const EXIT_COMPROMISE: i32 = 1;
pub const EXIT_WARN: i32 = 2;
pub const EXIT_INSUFFICIENT: i32 = 3;
pub const EXIT_INVALID: i32 = 4;
