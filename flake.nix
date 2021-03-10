{
  description = "A very basic flake";
  inputs.fu.url = "github:numtide/flake-utils/master";
  outputs = { self, nixpkgs, fu, ... }:
    with fu.lib;
    with nixpkgs.lib;
    eachSystem [ "x86_64-linux" ] (system:
      let version = "${substring 0 8 self.lastModifiedDate}.${self.shortRev or "dirty"}";
          overlay = final: _:
            with final;
            with haskellPackages;
            with haskell.lib;
            {
              apps = recurseIntoAttrs ({
                concurrency-primitive-benchmarks =
                  overrideCabal (callCabal2nix "concurrency-primitive-benchmarks" ./. {})
                    (o: { version = o.version + "-" + version; });
              });
            };
          overlays = [ overlay ];
      in
        with (import nixpkgs { inherit system overlays; });
        rec {
          packages = flattenTree (recurseIntoAttrs {
            inherit apps;
          });
          defaultPackage = packages."apps/concurrency-primitive-benchmarks";
        }
    );
}
