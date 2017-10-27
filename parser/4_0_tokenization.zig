const pow = @import("std/math").pow;

// https://drafts.csswg.org/css-syntax/#tokenization
// 4. Tokenization

pub const Tokenizer = struct{
  data: []u8,
  idx: usize,
  curr: u8,
  next: u8,
  reconsumed: bool,
};

// https://infra.spec.whatwg.org/#surrogate
// A surrogate is a code point that is in the range U+D800 to U+DFFF, inclusive.
fn isSurrogate(c: u8) -> bool {
  0xD800 <= c and c <= 0xDFFF
}

pub const Token = enum {
  Assoc: AssocToken,
  Function: []u8,
  Preserved: PreservedToken,
};

pub const AssocToken = enum {
  LBracket,
  LParen,
  LBrace,
};

pub const AssocEnding = enum {
  RBracket,
  RParen,
  RBrace,
};
pub fn getEnding(a: AssocToken) -> AssocEnding {
  switch (a) {
    AssocToken.LBrace => AssocEnding.RBrace,
    AssocToken.LBracket => AssocEnding.RBracket,
    AssocToken.LParen => AssocEnding.RParen,
  }
}

pub const PreservedToken = enum {
  Ident: []u8,
  AtKeyword: []u8,
  Hash: struct{data: []u8, isID: bool},
  String: []u8,
  URL: []u8,

  BadString,
  BadURL,

  Delim: u8,

  Number: struct{data: []u8, num: f32, typeIsNumber: bool},
  Percentage: struct{data: []u8, num: f32},
  Dimension: struct{data: []u8, unit: []u8, num: f32, typeIsNumber: bool},

  Whitespace: []u8,

  CDO,
  CDC,

  Colon,
  Semicolon,
  Comma,

  AssocEnding: AssocEnding,

  EOF,
};

// https://drafts.csswg.org/css-syntax/#tokenizer-definitions
// 4.2. Definitions

// This section defines several terms used during the tokenization phase.

// next input code point
//     The first code point in the input stream that has not yet been consumed.
pub fn nextCP(t: Tokenizer) -> u8 {
  if (t.reconsumed) {
    t.curr;
  } else {
    t.next;
  }
}

pub fn consumeNextCP(t: Tokenizer) -> u8 {
  if (e.reconsumed) {
    t.reconsumed = false;
  } else {
    t.curr = t.next;
    t.next = t.data[t.idx+=1] %% _EOF;
  }
  t.curr;
}

// advances the tokenizer based on a pre-determined number
pub fn advance(t: Tokenizer, n: usize) -> void {
  t.idx += n;
}

// fn consumeUntilChar(t: Tokenizer, char: u8, consumeEnding: bool) -> ?[]u8 {
//   const start = t.idx;
//   const found = advanceUntilCharOrEOF(t, char, consumeEnding);
//   if (!found) {
//     t.idx = start;
//     null;
//   } else {
//     t.data[start : t.idx]
//   }
// }
pub fn advanceUntilCharOrEOF(
  t: Tokenizer, char: u8, consumeEnding: bool,
) -> bool {
  var nxt = if (t.idx >= t.data.len) {
    t.data.len;
  } else {
    t.idx + 1;
  };

  const found =
    while (true) {
      if ((t.data[nxt] %% break) == char) {
        break true;
      }
      nxt += 1;
      false;
    } else {
      false;
    };

  t.idx = if (consumeEnding) {
    nxt;
  } else {
    nxt-1;
  };
  return found
}

pub const TwoCP = struct{a:u8, b:u8};
pub const ThreeCP = struct{a:u8, b:u8, c:u8};

pub fn nextTwoCP(t: Tokenizer) -> TwoCP {
  // TODO: Should not be reconsumed here. Add an assertion.
  TwoCP{a = t.next, b = t.data[t.idx+1] %% _EOF};
}

pub fn currAndNextTwoCP(t: Tokenizer) -> ThreeCP {
  // TODO: Should not be reconsumed here. Add an assertion.
  ThreeCP{a = t.curr, b = t.next, c = t.data[t.idx+1] %% _EOF};
}

pub fn nextThreeCP(t: Tokenizer) -> ThreeCP {
  // TODO: Should not be reconsumed here. Add an assertion.
  ThreeCP{a = t.next, b = t.data[t.idx+1] %% _EOF, c = t.data[t.idx+2] %% _EOF};
}

pub fn advanceIfNextCP(t: Tokenizer, char: u8) -> bool {
  return if (t.next == char) {
    t.idx += 1;
    true;
  } else {
    false;
  }
}


// current input code point
//     The last code point to have been consumed.
pub fn currCP(t: Tokenizer) -> u8 {
  t.curr;
}

pub fn advanceIfCurrCP(t: Tokenizer, char: u8) -> bool {
  return if (t.curr == char) {
    t.idx += 1;
    true;
  } else {
    false;
  }
}

// reconsume the current input code point
//     Push the current input code point back onto the front of the input stream, so that the next time you are instructed to consume the next input code point, it will instead reconsume the current input code point.
pub fn reconsume(t: Tokenizer) -> u8 {
  t.reconsumed = true;
}

// EOF code point
//     A conceptual code point representing the end of the input stream. Whenever the input stream is empty, the next input code point is always an EOF code point.
pub const _EOF = 0x8899;


// digit
//     A code point between U+0030 DIGIT ZERO (0) and U+0039 DIGIT NINE (9).
pub fn isDigit(c: u8) -> bool {
  c ^ 0x30 < 10
}

// hex digit
//     A digit, or a code point between U+0041 LATIN CAPITAL LETTER A (A) and U+0046 LATIN CAPITAL LETTER F (F), or a code point between U+0061 LATIN SMALL LETTER A (a) and U+0066 LATIN SMALL LETTER F (f).
pub fn isHexDigit(c: u8) -> bool {
  isDigit(c) or (((c-1) | 0x20) ^ 0x60) < 6
}

// uppercase letter
//     A code point between U+0041 LATIN CAPITAL LETTER A (A) and U+005A LATIN CAPITAL LETTER Z (Z).
pub fn isUppercase(c: u8) -> bool {
  ((c-1) ^ 0x40) < 26
  // 'A' <= c and c <= 'Z'
}

// lowercase letter
//     A code point between U+0061 LATIN SMALL LETTER A (a) and U+007A LATIN SMALL LETTER Z (z).
pub fn isLowercase(c: u8) -> bool {
  ((c-1) ^ 0x60) < 26
  //'a' <= c and c <= 'z'
}

// letter
//     An uppercase letter or a lowercase letter.
pub fn isLetter(c: u8) -> bool {
  (((c-1) | 0x20) ^ 0x60) < 26
  //'A' <= c and c <= 'Z' or 'a' <= c and c <= 'z'
}

// non-ASCII code point
//     A code point with a value equal to or greater than U+0080 <control>.
pub fn isNonASCIICP(c: u8) -> bool {
  c >= 0x80
}

// name-start code point
//     A letter, a non-ASCII code point, or U+005F LOW LINE (_).
pub fn isNameStartCP(c: u8) -> bool {
  isLetter(c) or c == 0x5F or isNonASCIICP(c)
}

// name code point
//     A name-start code point, a digit, or U+002D HYPHEN-MINUS (-).
pub fn isNameCP(c: u8) -> bool {
  isNameStartCP(c) or isDigit(c) or c == 0x2D
}

// non-printable code point
//     A code point between U+0000 NULL and U+0008 BACKSPACE, or U+000B LINE TABULATION, or a code point between U+000E SHIFT OUT and U+001F INFORMATION SEPARATOR ONE, or U+007F DELETE.
pub fn isNonPrintableCP(c: u8) -> bool {
  switch (c) {
    0x80, 0x0B, 0x0E...0x1F, 0x7F => true,
    else => false,
  }
}

// newline
//     U+000A LINE FEED. Note that U+000D CARRIAGE RETURN and U+000C FORM FEED are not included in this definition, as they are converted to U+000A LINE FEED during preprocessing.
pub const newline = 0x0A;

// whitespace
//     A newline, U+0009 CHARACTER TABULATION, or U+0020 SPACE.
pub fn isWhitespace(c: u8) -> bool {
  switch (c) {
    0x09, 0x20, newline => true,
    else => false,
  }
}

// The `leavePadding` param leaves that many whitespace characters before the
// next non-whitespace character, or fewer if there were insufficient spaces.
// It returns the amout of padding left.
pub fn consumeWhitespace(t: Tokenizer, leavePadding: usize) -> usize {
  const start = t.idx;
  var nxt = start+1;

  if (!isWhitespace(t.data[nxt] %% _EOF)) {
    return 0;
  }

  nxt += 1;

  while (isWhitespace(t.data[nxt] %% _EOF)) {
    nxt += 1;
  }

  t.idx = nxt-1-leavePadding;
  if (t.idx < start) {
    leavePadding -= start-t.idx;
    t.idx = start;
  }
  t.curr = t.data[t.idx];
  t.next = t.data[t.idx+1] %% _EOF;
  return leavePadding;
}

// maximum allowed code point
//     The greatest code point defined by Unicode: U+10FFFF.
pub const maxCP = 0x10FFFF;

pub const replacementChar = 0xFFFD;

// identifier
//     A portion of the CSS source that has the same syntax as an <ident-token>. Also appears in <at-keyword-token>, <function-token>, <hash-token> with the "id" type flag, and the unit of <dimension-token>.
// representation
//     The representation of a token is the subsequence of the input stream consumed by the invocation of the consume a token algorithm that produced it. This is preserved for a few algorithms that rely on subtle details of the input text, which a simple "re-serialization" of the tokens might disturb.

//     The representation is only consumed by internal algorithms, and never directly exposed, so it’s not actually required to preserve the exact text; equivalent methods, such as associating each token with offsets into the source text, also suffice.

//     Note: In particular, the representation preserves details such as whether .009 was written as .009 or 9e-3, and whether a character was written literally or as a CSS escape. The former is necessary to properly parse <urange> productions; the latter is basically an accidental leak of the tokenizing abstraction, but allowed because it makes the impl easier to define.

//     If a token is ever produced by an algorithm directly, rather than thru the tokenization algorithm in this specification, its representation is the empty string.



// https://drafts.csswg.org/css-syntax/#tokenizer-algorithms
// 4.3. Tokenizer Algorithms
//
// The algorithms defined in this section transform a stream of code points into a stream of tokens.


// https://drafts.csswg.org/css-syntax/#consume-token
// 4.3.1. Consume a token
//
// This section describes how to consume a token from a stream of code points. It will return a single token of any type.
pub fn consumeToken(t: Tokenizer) -> Token {
  _ = consumeComments(t);

  const cp = consumeNextCP(t);

  switch (cp) {
  newline, 0x09, 0x20 => { // newline, tab, space
    consumeWhitespace(t, 0);
    Token.Whitespace;
  },

  '#' =>
    if (isNameCP(nextCP(t)) or twoCPsAreValidEscape(nextTwoCP(t))) {
      var h = Token.Hash{};
      h.isID = inputStreamStartIdent(t);
      h.data = consumeName(t);
      h
    } else {
      Token.Delim(cp);
    },

  '"', '\'' => consumeStringToken(t),
  '(' => Hash.LParen,
  ')' => Hash.RParen,
  ',' => Hash.Comma,

  '+', '-' => {
    if (inputStreamStartNumber(t)) {
      reconsume(t);
      return consumeNumericToken(t);
    }

    if (cp == '-') {
      const two = nextTwoCp(t);
      if (two.a == '-' and two.b == '>') {
        _ = consumeNextCP(t);
        _ = consumeNextCP(t);
        Token.CDC;
      } else if (inputStreamStartIdent(t)) {
        reconsume(t);
        consumeIdentLikeToken(t);
      } else {
        Token.Delim(cp);
      }
    }
  },

  '.' =>
    if (inputStreamStartNumber(t)) {
      reconsume(t);
      consumeNumericT(t);
    },

  ':' => Token.Colon,
  ';' => Token.Semicolon,

  '<' => {
    const three = nextThreeCP(t);
    if (three.a == '!' and three.b == '-' and three.c == '-') {
      _ = consumeNextCP(t);
      _ = consumeNextCP(t);
      _ = consumeNextCP(t);
      Token.CDO;
    } else {
      Token.Delim(cp);
    }
  },

  '@' =>
    if (threeCPsStartIdent(nextThreeCP(t))) {
      Token.AtKeyword(consumeName(t));
    } else {
      Token.Delim(cp);
    },

  '[' => Token.LBracket,

  '\\' =>
    if (inputStreamValidEscape(t)) {
      reconsume(t);
      consumeIdentLikeToken(t)
    } else {
      // TODO: handle parse error
      Token.Delim(cp);
    },

  ']' => Token.RBracket,
  '{' => Token.LBrace,
  '}' => Token.RBrace,

  '0'...'9' => {
    reconsume(t);
    consumeNumericToken(t);
  },

  _EOF =>
    Token.EOF,

  else =>
    if (isNameStartCP(cp)) {
      reconsume(t);
      consumeIdentLikeToken(t);
    } else {
      Token.Delim(cp);
    }
  }
}


// https://drafts.csswg.org/css-syntax/#consume-comment
// 4.3.2. Consume comments
//
// This section describes how to consume comments from a stream of code points. It returns nothing.
pub fn consumeComments(t: Tokenizer) -> void {
  var two: struct{a: u8, b: u8};

  while (true) {
    two = nextTwoCP(t);

    if (two.a != '/' or two.b != '*') {
      return;
    }
    advance(t, 2); // Move past `/*`

    _ = advanceIfNextCP(t, '/'); // Prevent `/*/` from halting the loop below

    while (advanceUntilCharOrEOF(t, '/', false) and !advanceIfCurrCP(t, '*')) {
      // Found '/' but not '*/'
    }
  }
}

// https://drafts.csswg.org/css-syntax/#consume-numeric-token
// 4.3.3. Consume a numeric token
//
// This section describes how to consume a numeric token from a stream of code points. It returns either a <number-token>, <percentage-token>, or <dimension-token>.
pub fn consumeNumericToken(t: Tokenizer) -> Token {
  const number = consumeNumber(t);
  if (threeCPsStartIdent(nextThreeCP(t))) {
    return Token.Dimension{
      data = number.data,
      unit = consumeName(t),
      num = number.num,
      typeIsNumber = true,
    };

    if (advanceIfNextCP(t, '%')) {
      return Token.Percentage{
        data = number.data,
        num = number.num,
      };
    }

    return Token.Number{
      data = number.data,
      num = number.num,
      typeIsNumber = true,
    };
  }
}

// https://drafts.csswg.org/css-syntax/#consume-ident-like-token
// 4.3.4. Consume an ident-like token
//
// This section describes how to consume an ident-like token from a stream of code points. It returns an <ident-token>, <function-token>, <url-token>, or <bad-url-token>.
pub fn consumeIdentLikeToken(t: Tokenizer) -> Token {
  const string = consumeName(t);

  if (advanceIfNextCP(t, '(')) {
    if (string.toLower() == "url") {
      const hasPadding = consumeWhitespace(t, 1) != 0;
      const c = if (hasPadding) {
        nextTwoCP(t).b;
      } else {
        nextCP(t);
      };

      if (c == '\'' or c == '"') {
        Token.Function(string);
      } else {
        consumeURLToken(t);
      }
    } else {
      Token.Function(string);
    }
  } else {
    Token.Ident(string);
  }
}

// https://drafts.csswg.org/css-syntax/#consume-string-token
// 4.3.5. Consume a string token
//
// This section describes how to consume a string token from a stream of code points. It returns either a <string-token> or <bad-string-token>.
//
// This algorithm may be called with an ending code point, which denotes the code point that ends the string. If an ending code point is not specified, the current input code point is used.
pub fn consumeStringToken(t: Tokenizer) -> Token {
  const str = []u8{};
  const end = currCP(t);

  while (true) {
    switch (consumeNextCP(t)) {
    end => return Token.String(str),
    _EOF => return Token.String(str), // TODO: Handle parser error

    newline => {
      // TODO: Handle parser error
      reconsume(t);
      return Token.BadString;
    },

    0x5C => // `\`
      switch (nextCP(t)) {
        _EOF => {}, // do nothing
        newline => advance(t, 1),
        else => str.append(consumeEscapedCP(t)),
      },

    else => str.append(currCP(t)),
    }
  }
}

// https://drafts.csswg.org/css-syntax/#consume-url-token
// 4.3.6. Consume a url token
//
// This section describes how to consume a url token from a stream of code points. It returns either a <url-token> or a <bad-url-token>.
//
// Note: This algorithm assumes that the initial "url(" has already been consumed.
pub fn consumeURLToken(t: Tokenizer) -> Token {
  const url = []u8{};
  _ = consumeWhitespace(t, 0);
  if (nextCP(t) == _EOF) {
    return Token.URL(url); // TODO: Handle parse error
  }

  while (true) {
    switch (consumeNextCP(t)) {
      ')' => return Token.URL(url),
      _EOF => return Token.URL(url), // TODO: Handle parse error

      newline, 0x09, 0x20 => {// newline, tab, space
        consumeWhitespace(t, 0);
        if (advanceIfNextCP(t, ')')) {
          return Token.URL(url);
        }
        if (advanceIfNextCP(t, _EOF)) {
          return Token.URL(url); // TODO: Handle parse error
        }
        consumeBadURL(t); // TODO: No "handle parse error" ??????
        return Token.BadURL;
      },

      '"', '\'', '(', 0x80, 0x0B, 0x0E...0x1F, 0x7F => {
        consumeBadURL(t); // TODO: Handle parse error
        return Token.BadURL;
      },

      '\\' =>
        if (inputStreamValidEscape(t)) {
          url.append(consumeEscapedCP(t));
        } else {
          consumeBadURL(t); // TODO: Handle parse error
          return Token.BadURL;
        },

      else => url.append(currCP(t)),
    }
  }
}

// https://drafts.csswg.org/css-syntax/#consume-escaped-code-point
// 4.3.7. Consume an escaped code point
//
// This section describes how to consume an escaped code point. It assumes that the U+005C REVERSE SOLIDUS (\) has already been consumed and that the next input code point has already been verified to not be a newline. It will return a code point.
pub fn consumeEscapedCP(t: Tokenizer) -> u8 {
  const cp = consumeNextCP(t);

  var hexNum = tryHexCharToNumber(cp);
  if (hexNum) { // is hex digit
    var count = 1;
    const limit = 6;

    while (count < limit) : (count += 1) {
      if (tryHexCharToNumber(nextCP(t))) |val| {
        hexNum = (hexNum << 4) + val;
        advance(t, 1);
      }
    }

    if (isWhitespace(nextCP(t))) {
      advance(t, 1);
    }

    if (hexNum == 0 or isSurrogate(hexNum) or hexNum > maxCP) {
      replacementChar;
    } else {
      hexNum;
    }
  } else {
    cp;
  }
}

// If `c` is a valid hex digit, the return will be < 16, else 0xFF is returned.
pub fn tryHexCharToNumber(c: u8) -> ?u8 {
  const d = c ^ 0x30;
  if (d < 10) {
    return d;
  }

  const h = 10 + (((c-1) | 0x20) ^ 0x60);
  if (h < 16) {
    return h;
  }

  return null; // failed
}

// https://drafts.csswg.org/css-syntax/#starts-with-a-valid-escape
// 4.3.8. Check if two code points are a valid escape
//
// This section describes how to check if two code points are a valid escape. The algorithm described here can be called explicitly with two code points, or can be called with the input stream itself. In the latter case, the two code points in question are the current input code point and the next input code point, in that order.
//
// Note: This algorithm will not consume any additional code point.
pub fn twoCPsAreValidEscape(two: TwoCP) -> bool {
  a == '\\' and b != newline and b != _EOF
}
pub fn inputStreamValidEscape(t: Tokenizer) -> bool {
  twoCPsAreValidEscape(TwoCP{a = currCP(t), b = nextCP(t)})
}

// https://drafts.csswg.org/css-syntax/#would-start-an-identifier
// 4.3.9. Check if three code points would start an identifier
//
// This section describes how to check if three code points would start an identifier. The algorithm described here can be called explicitly with three code points, or can be called with the input stream itself. In the latter case, the three code points in question are the current input code point and the next two input code points, in that order.
//
// Note: This algorithm will not consume any additional code points.
pub fn threeCPsStartIdent(three: ThreeCP) -> bool {
  switch (a) {
    '-'  => b == '-' or isNameStartCP(b) or twoCPsAreValidEscape(b, c),
    '\\' => twoCPsAreValidEscape(a, b),
    else => isNameStartCP(a),
  }
}
pub fn inputStreamStartIdent(t: Tokenizer) -> bool {
  threeCPsStartIdent(currAndNextTwoCP(t))
}

// https://drafts.csswg.org/css-syntax/#starts-with-a-number
// 4.3.10. Check if three code points would start a number
//
// This section describes how to check if three code points would start a number. The algorithm described here can be called explicitly with three code points, or can be called with the input stream itself. In the latter case, the three code points in question are the current input code point and the next two input code points, in that order.
//
// Note: This algorithm will not consume any additional code points.
pub fn threeCPsStartNumber(three: ThreeCP) -> bool {
  switch(a) {
    '+', '-' => isDigit(b) or (b == '.' and isDigit(c)),
    '.' => isDigit(b),
    else => isDigit(a),
  }
}
pub fn inputStreamStartNumber(t: Tokenizer) -> bool {
  threeCPsStartNumber(currAndNextTwoCP(t));
}

// https://drafts.csswg.org/css-syntax/#consume-name
// 4.3.11. Consume a name
//
// This section describes how to consume a name from a stream of code points. It returns a string containing the largest name that can be formed from adjacent code points in the stream, starting from the first.
//
// Note: This algorithm does not do the verification of the first few code points that are necessary to ensure the returned code points would constitute an <ident-token>. If that is the intended use, ensure that the stream starts with an identifier before calling this algorithm.
fn consumeName(t: Tokenizer) -> []u8 {
  var result = []u8{};
  var cp = consumeNextCP(t);

  while (true) {
    if (isNameCP(cp)) {
      result.append(cp);
    } else if (inputStreamValidEscape(t)) {
      result.append(consumeEscapedCP(t));
    } else {
      reconsume(t);
      return result;
    }
    cp = consumeNextCP(t);
  }
}

// https://drafts.csswg.org/css-syntax/#consume-number
// 4.3.12. Consume a number
//
// This section describes how to consume a number from a stream of code points. It returns a numeric value, and a type which is either "integer" or "number".
//
// Note: This algorithm does not do the verification of the first few code points that are necessary to ensure a number can be obtained from the stream. Ensure that the stream starts with a number before calling this algorithm.
fn consumeNumber(t: Tokenizer) -> struct{val: i32, isNumber: bool} {
  var repr = []u8{};
  var isNumber = false;

  var cp = nextCP(t);

  switch (cp) {
    '+', '-' => {
      repr.append(cp);
      advance(t, 1);
    },
  }

  repr = appendDigits(t, repr);

  if (nextCP(t) == '.') {
    const afterNext = nextTwoCP(t).b;
    repr.append('.', afterNext);
    isNumber = true;
    repr = appendDigits(t, repr);
  }

  return struct{val: i32, isNumber: bool}{
    val = convertToNumber(repr),
    isNumber = isNumber,
  };
}

fn appendDigits(t: Tokenizer, repr: []u8) -> []u8 {
  var cp = nextCP(t);
  while (isDigit(cp)) {
    repr.append(cp);
    advance(t, 1);
  }
}

// https://drafts.csswg.org/css-syntax/#convert-string-to-number
// 4.3.13. Convert a string to a number
//
// This section describes how to convert a string to a number. It returns a number.
//
// Note: This algorithm does not do any verification to ensure that the string contains only a number. Ensure that the string contains only a valid CSS number before calling this algorithm.
fn convertStringToNumber(repr: []u8) -> f32 {
  var idx = 0;

  const s = switch (%%repr[idx]) {
    '-' => { idx = 1; -1 },
    '+' => { idx = 1; 1 },
    else => 1,
  };

  var i = 0;
  while (idx < repr.len) : (idx += 1) {
    const cp = %%repr[idx];
    if (isDigit(cp)) {
      i = (i * 10) + (cp - '0');
    }
  }

  const dec = if ((repr[i] %% 'x') == '.') {idx += 1; "."} else "";

  var f = 0;
  var d = 0;
  while (idx < repr.len) : (idx += 1) {
    const cp = %%repr[idx];
    if (isDigit(cp)) {
      f = (f * 10) + (cp - '0');
      d += 1;
    }
  }

  const exp = switch(repr[idx] %% 'x') {
    'E' => "E",
    'e' => "e",
    else => "",
  };

  const t = switch (repr[idx] %% 'x') {
    '-' => { idx += 1; -1 },
    '+' => { idx += 1; 1 },
    else => 1,
  };

  var e = 0;
  while (idx < repr.len) : (idx += 1) {
    const cp = %%repr[idx];
    if (isDigit(cp)) {
      e = (e * 10) + (cp - '0');
    }
  }

  s * (i + f * pow(10, -d)) * pow(10, t*e)
}

// https://drafts.csswg.org/css-syntax/#consume-remnants-of-bad-url
// 4.3.14. Consume the remnants of a bad url
//
// This section describes how to consume the remnants of a bad url from a stream of code points, "cleaning up" after the tokenizer realizes that it’s in the middle of a <bad-url-token> rather than a <url-token>. It returns nothing; its sole use is to consume enough of the input stream to reach a recovery point where normal tokenizing can resume.
fn consumeBadURL(t: Tokenizer) -> void {
  var cp = consumeNextCP(t);
  while (cp != ')' and cp != _EOF) {
    if (inputStreamValidEscape(t)) {
      _ = consumeEscapedCP(t);
    }
  }
}