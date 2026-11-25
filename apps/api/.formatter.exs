[
  import_deps: [:ecto, :ecto_sql, :phoenix, :absinthe],
  subdirectories: ["priv/*/migrations"],
  plugins: [Absinthe.Formatter],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}", "priv/*/seeds.exs"],
  line_length: 120
]
