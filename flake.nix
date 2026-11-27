{
  description = "Rust UEFI OS development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    rust-overlay,
    ...
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (
        system:
          f (import nixpkgs {
            inherit system;
            overlays = [(import rust-overlay)];
          })
      );
  in {
    devShells = forAllSystems (pkgs: let
      rustToolchain = pkgs.rust-bin.stable.latest.default.override {
        extensions = [
          "rust-src"
          "rust-analyzer"
          "clippy"
          "rustfmt"
        ];
        targets = ["x86_64-unknown-uefi"];
      };
    in {
      default = pkgs.mkShell {
        packages = [
          rustToolchain
          pkgs.pkg-config
          pkgs.qemu
        ];

        RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
        OVMF_CODE = "${pkgs.qemu}/share/qemu/edk2-x86_64-code.fd";

        shellHook = ''
          export CARGO_HOME="$PWD/.direnv/cargo"
          mkdir -p "$CARGO_HOME"
          echo "⚡ [Rust Dev Environment Loaded]"
          echo "  • Rust:  $(rustc --version 2>/dev/null || echo 'ready')"
          echo "  • Cargo: $(cargo --version 2>/dev/null || echo 'ready')"
          echo "  • Cargo home: $CARGO_HOME"
        '';
      };
    });
  };
}
