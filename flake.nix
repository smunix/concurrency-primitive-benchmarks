{
  description = "A very basic flake";
  inputs.fu.url = "github:numtide/flake-utils/master";
  outputs = { self, nixpkgs, fu, ... }:
    with fu.lib;
    with nixpkgs.lib;
    eachSystem [ "x86_64-linux" ] (system:
      let version = "${substring 0 8 self.lastModifiedDate}.${self.shortRev or "dirty"}";
          overlay = compilers: final: _:
            with final;
            with haskell.lib;
            let apply =
                  compiler:
                  with haskell.packages."${compiler}".extend(hself: hsuper:
                    with hself;
                    {
                      text-short = dontHaddock (dontCheck (hsuper.text-short)) ;
                    }); 
                  recurseIntoAttrs ({
                    concurrency-primitive-benchmarks =
                      overrideCabal (callCabal2nix "concurrency-primitive-benchmarks" ./. {})
                        (o: { version = o.version + "-${compiler}-" + version; });
                  });
            in
            {
              apps = recurseIntoAttrs (listToAttrs (map (compiler: { name = "${compiler}"; value = apply compiler; }) compilers));
            };
          compilers = ["ghc8103" "ghc8104" "ghc901"];
          overlays = [ (overlay compilers) ];
      in
        with (import nixpkgs { inherit system overlays; });
        rec {
          packages = flattenTree (recurseIntoAttrs { inherit apps; });
          defaultPackage = packages."apps/ghc8104/concurrency-primitive-benchmarks";
        }
    );
}
