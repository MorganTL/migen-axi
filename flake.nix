{
  description = "A leading-edge control system for quantum information experiments";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    artiq.url = "git+https://github.com/m-labs/artiq.git";
  };

  outputs =
    {
      self,
      nixpkgs,
      artiq,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
      artiqpkgs = artiq.packages.x86_64-linux;

      migen-axi = pkgs.python3Packages.buildPythonPackage {
        pname = "migen-axi";
        version = "unstable-2023-01-06";

        src = ./.;

        format = "pyproject";

        propagatedBuildInputs = with pkgs.python3Packages; [
          setuptools
          click
          numpy
          toolz
          jinja2
          ramda
          artiqpkgs.migen
          artiqpkgs.misoc
        ];

        checkInputs = with pkgs.python3Packages; [
          pytestCheckHook
          pytest-timeout
        ];

        # migen/misoc version checks are broken with pyproject for some reason
        postPatch = ''
          sed -i "1,4d" pyproject.toml
          substituteInPlace pyproject.toml \
            --replace '"migen@git+https://github.com/m-labs/migen",' ""
          substituteInPlace pyproject.toml \
            --replace '"misoc@git+https://github.com/m-labs/misoc.git",' ""
          # pytest-flake8 is broken with recent flake8. Re-enable after fix.
          substituteInPlace setup.cfg --replace '--flake8' ""
        '';
      };

      ramda = pkgs.python3Packages.buildPythonPackage {
        pname = "ramda";
        version = "unstable-2020-04-11";

        src = pkgs.fetchFromGitHub {
          owner = "peteut";
          repo = "ramda.py";
          rev = "d315a9717ebd639366bf3fe26bad9e3d08ec3c49";
          sha256 = "sha256-bmSt/IHDnULsZjsC6edELnNH7LoJSVF4L4XhwBAXRkY=";
        };

        nativeBuildInputs = with pkgs.python3Packages; [ pbr ];
        propagatedBuildInputs = with pkgs.python3Packages; [
          future
          fastnumbers
        ];

        checkInputs = with pkgs.python3Packages; [ pytest ];
        checkPhase = "pytest";
        doCheck = false;

        preBuild = ''
          export PBR_VERSION=0.5.5
        '';
      };

    in
    {
      packages.${system} = {
        inherit migen-axi;
      };
      devShells.${system} = {
        default = pkgs.mkShell {
          name = "migen-axi-dev-shell";
          buildInputs = with pkgs; [
            gnumake
            (python3.withPackages (
              ps:
              (with artiqpkgs; [
                migen
                misoc
                artiq
                ramda
                ps.pytest
                ps.jsonschema
                ps.pyftdi
                ps.click
                ps.jinja2
                ps.numpy
                ps.pytestCheckHook
                ps.pytest-timeout
                ps.setuptools
                ps.toolz
              ])
            ))
            artiqpkgs.artiq
          ];
        };
      };
    };
}
