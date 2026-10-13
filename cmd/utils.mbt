///|
// fn write_text_file(path : StringView, str : StringView) -> Unit raise {
//   let fd = @wasi.Fd::open(
//     path.to_string(),
//     open_flags=@wasi.OpenFlags::new().set(Create).set(Trunc),
//     rights=@wasi.Rights::new().set(Fd_write),
//   ) catch {
//     e => reraise(e)
//   }
//   let data = @encoding/utf8.encode(str)
//   let mut written = 0
//   while written < data.length() {
//     let n = fd.fd_write([data[written:]]) catch { e => reraise(e) }
//     written += n.0.reinterpret_as_int()
//   }
// }

///|
// fn read_text_file(path : StringView) -> String raise {
//   let fd = @wasi.Fd::open(
//     path.to_string(),
//     rights=@wasi.Rights::new().set(Fd_read).set(Fd_filestat_get),
//   ) catch {
//     e => reraise(e)
//   }
//   let stat = fd.fd_filestat_get() catch { e => reraise(e) }
//   let size = stat.size
//   let buffer = FixedArray::make(size.0.to_int(), b'\x00')
//   let buf = FixedArray::make(1024, b'\x00')
//   let mut read = 0UL
//   while read < size.0 {
//     let n = fd.fd_read([buf]) catch { e => reraise(e) }
//     buf.blit_to(buffer, len=n.0.reinterpret_as_int(), dst_offset=read.to_int())
//     read += n.0.to_uint64()
//   }
//   @encoding/utf8.decode(buffer.unsafe_reinterpret_as_bytes()) catch {
//     e => reraise(e)
//   }
// }

// ///|
// fn @wasi.Fd::open(
//   path : String,
//   open_flags? : @wasi.OpenFlags = @wasi.OpenFlags::new(),
//   rights? : @wasi.Rights = @wasi.Rights::new(),
// ) -> @wasi.Fd raise {
//   for i = 3; ; i = i + 1 {
//     let dir = @wasi.Fd(i).fd_prestat_dir_name() catch {
//       Badf => fail("Failed to find preopened directories")
//       e => fail_with("Failed to find preopened directories", e)
//     }
//     let dir = dir.trim(char_set="\u{0}") // for wasmer
//     if path.strip_prefix(dir) is Some(rel_path) {
//       let rel_path = if rel_path is ['/', ..] { rel_path[1:] } else { rel_path }
//       return @wasi.Fd(i).path_open(
//         @wasi.LookupFlags::new(),
//         rel_path.to_string(),
//         open_flags,
//         rights,
//         @wasi.Rights::new(),
//         @wasi.FdFlags::new(),
//       ) catch {
//         e => fail_with("Failed to open file '\{path}'", e)
//       }
//     } else {
//       continue
//     }
//   }
// }

///|
pub fn eprintln(msg : String) -> Unit {
  let data = @encoding/utf8.encode(msg + "\n")
  let mut written = 0
  while written < data.length() {
    let n = @wasi.stderr.fd_write([data[written:]]) catch { _ => return }
    written += n.0.reinterpret_as_int()
  }
}

///|
pub fn[T] exit(code : Int32) -> T {
  @wasi.proc_exit(code.reinterpret_as_uint())
  panic()
}

///|
pub fn println(msg : String) -> Unit {
  let data = @encoding/utf8.encode(msg + "\n")
  let mut written = 0
  while written < data.length() {
    let n = @wasi.stdout.fd_write([data[written:]]) catch { _ => return }
    written += n.0.reinterpret_as_int()
  }
}

///|
pub fn read_input() -> String raise {
  let fd = @wasi.stdin
  let buffer = @buffer.new(size_hint=1024)
  let buf = FixedArray::make(1024, b'\x00')
  while true {
    let n = fd.fd_read([buf]) catch { e => reraise(e) }
    let read = n.0.to_uint64()
    if read == 0 {
      break
    } else {
      buffer.write_bytesview(buf.unsafe_reinterpret_as_bytes()[:read.to_int()])
    }
  }
  @encoding/utf8.decode(buffer.to_bytes()) catch {
    e => reraise(e)
  }
}

// ///|
// fn[T] abort(msg : String) -> T {
//   eprintln(msg)
//   exit(1)
// }
