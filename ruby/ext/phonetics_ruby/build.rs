fn main() {
    // rb-sys-env 0.2 reads RUBY_VERSION, but the rb_sys gem's mkmf
    // Makefile only exports the split form (RBCONFIG_MAJOR/MINOR/TEENY).
    // Reconstruct it from RBCONFIG_* when needed so both invocation
    // paths (standalone `cargo build` and gem-extconf-driven `make`)
    // work without the caller having to know which one to set.
    if std::env::var_os("RUBY_VERSION").is_none() {
        if let (Ok(major), Ok(minor), Ok(teeny)) = (
            std::env::var("RBCONFIG_MAJOR"),
            std::env::var("RBCONFIG_MINOR"),
            std::env::var("RBCONFIG_TEENY"),
        ) {
            std::env::set_var("RUBY_VERSION", format!("{major}.{minor}.{teeny}"));
        }
    }

    let _ = rb_sys_env::activate().expect("phonetics-ruby: cannot locate a Ruby");

    // macOS native-extension linker behaviour: leave Ruby's `rb_*`
    // symbols unresolved until dlopen time.
    if cfg!(target_os = "macos") {
        println!("cargo:rustc-link-arg=-Wl,-undefined,dynamic_lookup");
    }
}
