fn main() -> std::io::Result<()> {
    prost_build::compile_protos(&["../../proto/readings.proto"], &["../../proto"])
}
