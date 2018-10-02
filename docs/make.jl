using Documenter, Devices
using FileIO

makedocs()

deploydocs(
    deps   = Deps.pip("mkdocs", "mkdocs-material", "python-markdown-math"),
    julia  = "0.7",
    osname = "linux",
    repo   = "github.com/PainterQubits/Devices.jl.git"
)
