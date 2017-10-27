use @import("./5_0_parsing.zig");
const io = @import("std").io;

pub fn main() -> %void {
  %%io.stdout.printf("foobar\n");
  const ss = ParseStylesheet(
    EntryData.String("#foo { font-weight: bold }"),
  );


}