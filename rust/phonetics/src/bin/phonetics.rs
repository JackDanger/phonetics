//! `phonetics` CLI binary, Rust edition.
//!
//! Same interface as `ruby/bin/phonetics`. The Ruby integration tests
//! in `ruby/spec/phonetics/cli_spec.rb` shell out to a binary and
//! parse its stdout — they don't care what language that binary is
//! written in. Pointing them at this binary should produce the same
//! 34 green tests.

use std::process::ExitCode;

const USAGE: &str = "\
Usage: phonetics <command> [args...]

Phrase-level distances (input: IPA strings, possibly with spaces):
  distance    <ipa1> <ipa2>     Strict phonetic Levenshtein.
  confusion   <ipa1> <ipa2>     Listener-confusion distance.
  similarity  <ipa1> <ipa2>     0..1 normalised similarity.

Phoneme-level distances (input: single phonemes):
  phoneme         <a> <b>       Acoustic distance.
  phoneme-conf    <a> <b>       Perceptual distance (with overlay).

Tokenisation:
  tokenize    [--boundaries] <ipa>     Phoneme stream, one per line.

Numeric output is a single line. With --json, output is a JSON object.
";

fn main() -> ExitCode {
    let mut args: Vec<String> = std::env::args().skip(1).collect();

    let json = remove_flag(&mut args, "--json");
    let boundaries = remove_flag(&mut args, "--boundaries");

    let Some(command) = args.first().cloned() else {
        print!("{USAGE}");
        return ExitCode::SUCCESS;
    };
    let rest = &args[1..];

    match command.as_str() {
        "--help" | "-h" => {
            print!("{USAGE}");
            ExitCode::SUCCESS
        }
        "version" | "--version" => {
            println!("{}", env!("CARGO_PKG_VERSION"));
            ExitCode::SUCCESS
        }
        "distance" => need_two(rest).map_or_else(|| usage_error("distance"), |(a, b)| {
            print_number(phonetics::levenshtein(a, b), json);
            ExitCode::SUCCESS
        }),
        "confusion" => need_two(rest).map_or_else(|| usage_error("confusion"), |(a, b)| {
            print_number(phonetics::confusion(a, b), json);
            ExitCode::SUCCESS
        }),
        "similarity" => need_two(rest).map_or_else(|| usage_error("similarity"), |(a, b)| {
            print_number(phonetics::similarity(a, b), json);
            ExitCode::SUCCESS
        }),
        "phoneme" => need_two(rest).map_or_else(|| usage_error("phoneme"), |(a, b)| {
            print_number(phonetics::distance(a, b), json);
            ExitCode::SUCCESS
        }),
        "phoneme-conf" => need_two(rest).map_or_else(|| usage_error("phoneme-conf"), |(a, b)| {
            print_number(phonetics::confusion::sub_cost(a, b), json);
            ExitCode::SUCCESS
        }),
        "tokenize" => {
            let Some(input) = rest.first() else {
                return usage_error("tokenize");
            };
            let toks = phonetics::tokens(input, boundaries);
            if json {
                let payload = json_tokens(&toks);
                println!("{payload}");
            } else {
                for t in toks {
                    println!("{t}");
                }
            }
            ExitCode::SUCCESS
        }
        unknown => {
            eprintln!("phonetics: unknown command {unknown:?}\n\n{USAGE}");
            ExitCode::from(2)
        }
    }
}

fn remove_flag(args: &mut Vec<String>, flag: &str) -> bool {
    if let Some(pos) = args.iter().position(|a| a == flag) {
        args.remove(pos);
        true
    } else {
        false
    }
}

fn need_two(args: &[String]) -> Option<(&str, &str)> {
    if args.len() == 2 {
        Some((args[0].as_str(), args[1].as_str()))
    } else {
        None
    }
}

fn usage_error(name: &str) -> ExitCode {
    eprintln!("phonetics {name}: expected two arguments\n\n{USAGE}");
    ExitCode::from(2)
}

fn print_number(v: f64, json: bool) {
    if json {
        println!("{{\"value\":{v}}}");
    } else {
        println!("{v}");
    }
}

fn json_tokens(toks: &[String]) -> String {
    let inner: Vec<String> = toks
        .iter()
        .map(|t| format!("\"{}\"", t.replace('\\', "\\\\").replace('"', "\\\"")))
        .collect();
    format!("{{\"tokens\":[{}]}}", inner.join(","))
}
