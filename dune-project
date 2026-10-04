(lang dune 3.24)
(name cutline)
(generate_opam_files false)

(package
 (name cutline)
 (synopsis "I measure route changes in a local street graph")
 (depends
  (ocaml (>= 5.5.1))
  (alcotest :with-test)))
