use @import("./4_0_tokenization.zig");


fn ParseAnPlusB(p: Parser) -> %AnPlusB {
  var ab = AnPlusB{};
  ab.parse(p, false);
  ab;
}

const AnPlusB = struct {
  a: i32,
  b: i32,

  pub fn string(self: &const AnPlusB) -> string {
    a.string() + (if (b >= 0) "n+" else "n") + b.string()
  }

  fn parse(self: &AnPlusB, p: Parser, comptime have_plus: bool) -> %void {
    // If we had a leading '+', do not consume whitespace, since it should be
    //  consumed in the switch below, causing an error.
    if (!have_plus) {
      skipWhitespace(p);
    }

    switch (consumeToken(p)) {
      Token.Delim => |delim| {
        if (have_plus or delim != '+')
          return error.SyntaxError
        else
          self.parse(p, true) // recursive call indicating '+' was found
      },

      Token.Number => |n|
        if (have_plus or n.is_number) {
          return error.SyntaxError
        } else {
          self.a = 0;
          self.b = n.num.i32(); // 0, <integer>
        },

      Token.Dimension => |d|
        if (have_plus or d.is_number) {
          return error.SyntaxError
        } else {
          // <n-dimension>
          // <n-dimension> <signed-integer>
          // <n-dimension> ['+' | '-'] <signless-integer>
          // <ndash-dimension> <signless-integer>
          // <ndashdigit-dimension>
          self.a = d.num.i32();
          self.parse_b("n-", d.unit.lower(), p);
        },

      Token.Ident => |ident|
        const lower_ident = ident.lower();

        // Start with those that start with a '-'
        if ((%%ident[0]) == '-') {
          if (have_plus) {
            return error.SyntaxError
          } else {
            // -n
            // -n <signed-integer>
            // -n ['+' | '-'] <signless-integer>
            // -n- <signless-integer>
            // <dashndashdigit-ident>
            self.a = -1;
            self.parse_b("-n-", lower_ident, p);
          }

        } else switch (lower_ident) {
          "odd"  =>
            if (have_plus) {
              return error.SyntaxError;
            } else {
              self.a = 2;
              self.b = 1;
            },
          "even" =>
            if (have_plus) {
              return error.SyntaxError;
            } else {
              self.a = 2;
              self.b = 0;
            },

          else => {
            // +?n
            // +?n <signed-integer>
            // +?n ['+' | '-'] <signless-integer>
            // +?n- <signless-integer>
            // +?<ndashdigit-ident>
            self.a = 1;
            self.parse_b("n-", lower_ident, p);
          },
        },

      else =>
        return error.SyntaxError,
    }

    skipWhitespace(p);

    if (consumeToken(p) != Token.EOF) {
      return error.SyntaxError;
    }
  }


  // `pattern` is either "n-" or "-n-" and must begin the `s` string. If needed,
  // the last `-` and its subsequent digits are parsed. Any failure means `None`.
  fn parse_b(self: &AnPlusB, pattern: string, str: []u8, p: Parser) %void {
    switch (str) {
      "n", "-n"   => return self.b_opt_signed_or_delim_signless_integer(p),
      "n-", "-n-" => return self.b_signless_integer(true, p),
      else =>
        if (str.startsWith(pattern)) {
          // Parse the remainder of `str` (including the '-') into an I32
          self.b = str.substring(pattern.size().isize()-1).i32(10);
          return;
        },
    }
    error.SyntaxError;
  }


  // `b` is already known to be pos or neg, so this function just checks that the
  // next-after-space token is a Number/Integer that start with a digit.
  fn b_signless_integer(self: &AnPlusB, is_neg: bool, p: Parser) -> %void {
    skipWhitespace(p);

    switch (consumeToken(p)) {
      Token.Number => |n|
        if (!n.is_number and isDigit(%%n.repr[0])) { // [-+]<signless-integer>
          self.b = (if (is_neg) -1 else 1) * n.num.i32());
          return;
        }
    }
    error.SyntaxError;
  }


  // `b` is optional (EOF), a signed Int or a +- Delim followed by a signless Int
  fn b_opt_signed_or_delim_signless_integer(
    self: &AnPlusB, p: Parser,
  ) -> %void {

    skipWhitespace(p);

    switch (consumeToken(p)) {
      Token.EOF => {
        self.b = 0; // a, 0
        return;
      },

      Token.Number => |n|
        if (!n.is_number) {
          const c = %%n.repr[0];
          if (c == '+' or c == '-') {
            self.b = n.num.i32(); // a, <signed-integer>
            return;
          }
        }

      Token.Delim => |d|
        if (d.delim == '+' or d.delim == '-') {
          return self.b_signless_integer(d.delim == '-', p);
        }
    }
    error.SyntaxError
  }

}