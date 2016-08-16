import PackageDescription

let package = Package(
    name: "Apex",
    dependencies: [
        .Package(url: "https://github.com/VeniceX/CLibvenice.git", Version(0, 6, 2)),
    ]
)
