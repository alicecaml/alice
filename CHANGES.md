# Changelog

## Unreleased

### Fixed

- Replace panics with user exceptions in some cases
- Detect case when the name of a dependency doesn't match the name of the specified package

## 0.3.0

### Changed

- Follow the XDG convention when installing tools.

### Fixed

- Update dot-merlin-reader on windows to fix crash on launch.
- Fix issue running `alice tools exec` on windows in CMD.exe.

## 0.2.0

### Added

- Generate files necessary to support ocamllsp.

### Changed

- Switch to github for hosting tool archives.
- Display progress bar while downloading tools.

## 0.1.3

### Added

- Add a patch that replaces the locked compiler version with a template string to simplify packaging

## 0.1.2

### Added

- Release a zip archive on windows with just alice.exe

## 0.1.1

### Fixed

- External commands are run in an environment containing the OCaml toolchain if
  Alice has installed an OCaml toolchain. This fixes an issue where the OCaml
  compiler couldn't find flexlink on Windows unless the current Alice root was
  in the PATH variable. (#2, fixes #1)
- Fixed compile error on 32-bit machines due to unrepresentable integer literal.
- Wrap text in help messages.

## 0.1.0

### Added

- Initial release of Alice. Multi-file packages with dependencies specified
  within the local filesystem can be built and incrementally rebuilt.
  Dependency and build graphs can be visualized with graphviz. The OCaml
  toolchain and some development tools can be installed user-wide.
