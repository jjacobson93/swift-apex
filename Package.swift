import PackageDescription

let package = Package(
    name: "Apex",
    dependencies: [
        .Package(url: "https://github.com/VeniceX/Venice.git", majorVersion: 0, minor: 5),
        .Package(url: "https://github.com/VeniceX/File.git", majorVersion: 0, minor: 5),
        .Package(url: "https://github.com/Zewo/JSON.git", majorVersion: 0, minor: 5),
    ]
)
