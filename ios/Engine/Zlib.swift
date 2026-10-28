import Compression
import Foundation

// CompressionStream('deflate') on the website = zlib format (2-byte header, raw deflate, Adler-32). Apple's ZLIB is the raw part.
private func adler32(_ d: Data) -> UInt32 { var a: UInt32 = 1, b: UInt32 = 0; for x in d { a = (a + UInt32(x)) % 65521; b = (b + a) % 65521 }; return (b << 16) | a }
private func run(_ input: Data, _ op: compression_stream_operation) -> Data? {
    var st = compression_stream(dst_ptr: UnsafeMutablePointer<UInt8>(bitPattern: 1)!, dst_size: 0, src_ptr: UnsafePointer<UInt8>(bitPattern: 1)!, src_size: 0, state: nil)
    guard compression_stream_init(&st, op, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else { return nil }
    defer { compression_stream_destroy(&st) }
    var out = Data(); let cap = 64 * 1024
    let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: cap); defer { buf.deallocate() }
    return input.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Data? in
        st.src_ptr = src.bindMemory(to: UInt8.self).baseAddress ?? UnsafePointer<UInt8>(bitPattern: 1)!; st.src_size = input.count
        while true {
            st.dst_ptr = buf; st.dst_size = cap
            let s = compression_stream_process(&st, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
            out.append(buf, count: cap - st.dst_size)
            if s == COMPRESSION_STATUS_END { return out }
            if s == COMPRESSION_STATUS_ERROR { return nil }
        }
    }
}
func zlibDeflate(_ d: Data) -> Data? {
    guard let raw = run(d, COMPRESSION_STREAM_ENCODE) else { return nil }
    var out = Data([0x78, 0x9C]); out.append(raw)
    let a = adler32(d); out.append(contentsOf: [UInt8(a >> 24), UInt8((a >> 16) & 255), UInt8((a >> 8) & 255), UInt8(a & 255)])
    return out
}
func zlibInflate(_ d: Data) -> Data? {
    guard d.count > 6 else { return nil }
    return run(d.subdata(in: 2..<(d.count - 4)), COMPRESSION_STREAM_DECODE)
}
