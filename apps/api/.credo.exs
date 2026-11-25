%{
  configs: [
    %{
      name: "default",
      files: %{included: ["lib/", "test/", "config/"], excluded: [~r"/_build/", ~r"/deps/"]},
      strict: true,
      checks: %{
        enabled: [
          {Credo.Check.Refactor.Nesting, [max_nesting: 4]},
          {Credo.Check.Refactor.CyclomaticComplexity, [max_complexity: 20]},
          {Credo.Check.Refactor.FunctionArity, [max_arity: 10]},
          {Credo.Check.Readability.MaxLineLength, [max_length: 160, ignore_strings: true]}
        ],
        disabled: [
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.Specs, []},
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Design.AliasUsage, []},
          {Credo.Check.Refactor.CondStatements, []},
          {Credo.Check.Readability.WithSingleClause, []}
        ]
      }
    }
  ]
}
