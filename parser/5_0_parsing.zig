use @import("./4_0_tokenization.zig");

// https://drafts.csswg.org/css-syntax/#parsing
// 5. Parsing
//
// The input to the parsing stage is a stream or list of tokens from the tokenization stage. The output depends on how the parser is invoked, as defined by the entry points listed later in this section. The parser output can consist of at-rules, qualified rules, and/or declarations.
//
// The parser’s output is constructed according to the fundamental syntax of CSS, without regards for the validity of any specific item. Implementations may check the validity of items as they are returned by the various parser algorithms and treat the algorithm as returning nothing if the item was invalid according to the implementation’s own grammar knowledge, or may construct a full tree as specified and "clean up" afterwards by removing any invalid items.


const EntryData = enum {
  Tokenizer: Tokenizer,
  CVs: []ComponentValue,

  fn nextToken(self: EntryData) -> Token {
    comptime switch(self) {
      Tokenizer => |tok| nextToken(tok),
      CVs => |c| c.shift() %% Token.EOF,
    }
  }
};

export fn NewParser(comptime T: type, data: &T) -> type {
  return Parser {
    .source = switch(T) {
      []u8             => |d| EntryData.Tokenizer(Tokenizer(d)),
      Tokenizer        => |d| EntryData.Tokenizer(d),
      []ComponentValue => |d| EntryData.CVs(d),
    },
    .curr = undefined,
    .next = undefined,
    .reconsumed = false,
  };
}

pub const AtRule = struct {
  name: []u32,
  prelude: []ComponentValue,
  block: ?SimpleBlock,
};

pub const QualifiedRule = struct {
  prelude: []ComponentValue,
  block: SimpleBlock,
};

pub const Declaration = struct {
  name: []u32,
  value: []ComponentValue,
  is_important: bool,
};

pub const ComponentValue = enum {
  Preserved: PreservedToken,
  Function: struct{name: []u32, value: []ComponentValue},
  SimpleBlock: struct{assoc_token: AssocToken, value: []ComponentValue},
};

pub const Parser = struct {
  source: EntryData,
  curr: Token,
  next: Token,
  reconsumed: bool,

  // https://drafts.csswg.org/css-syntax/#parser-definitions
  // 5.2. Definitions

  // current input token
  //     The token or component value currently being operated on, from the list of tokens produced by the tokenizer.
  fn currToken(self: &const Parser) -> Token {
    self.curr;
  }

  // next input token
  //     The token or component value following the current input token in the list of tokens produced by the tokenizer. If there isn’t a token following the current input token, the next input token is an <EOF-token>.
  fn nextToken(self: &const Parser) -> Token {
    if (self.reconsumed) {
      return self.curr;
    }
    return self.next;
  }

  // <EOF-token>
  //     A conceptual token representing the end of the list of tokens. Whenever the list of tokens is empty, the next input token is always an <EOF-token>.

  // consume the next input token
  //     Let the current input token be the current next input token, adjusting the next input token accordingly.
  fn consumeToken(self: &Parser) -> Token {
    if (self.reconsumed) {
      self.reconsumed = false;
    } else {
      self.curr = self.next;
      self.next = nextToken(self.source);
    }
    self.curr;
  }

  // reconsume the current input token
  //     The next time an algorithm instructs you to consume the next input token, instead do nothing (retain the current input token unchanged).
  fn reconsume(self: &Parser) {
    self.reconsumed = true;
  }



  // https://drafts.csswg.org/css-syntax/#parser-entry-points
  // 5.3. Parser Entry Points
  // The algorithms defined in this section produce high-level CSS objects from lower-level objects. They assume that they are invoked on a token stream, but they may also be invoked on a string; if so, first perform input preprocessing to produce a code point stream, then perform tokenization to produce a token stream.
  //
  // "Parse a stylesheet" can also be invoked on a byte stream, in which case The input byte stream defines how to decode it into Unicode.
  //
  // All of the algorithms defined in this spec may be called with either a list of tokens or of component values. Either way produces an identical result.


  fn skipWhitespace(self: &Parser) {
    while (true) {
      switch (self.nextToken()) {
        Token.Whitespace => self.consumeToken(),
        else => return
      }
    }
  }

  // https://drafts.csswg.org/css-syntax/#parse-stylesheet
  // 5.3.2. Parse a stylesheet
  pub fn ParseStylesheet(comptime T: type, data: T) -> Stylesheet {
    var p = ParserFromEntryData(d);
    var ss = Stylesheet{};
    const rules = consumeListOfRules(p, true);
    if (rules.len != 0) {
      switch (rules[0]) {
        Token.AtRule => |ar|
          if (ar.name == "charset") {
            rules.shift();
          }
      }
    }

    ss.value = rules;
    return ss;
  }

  // https://drafts.csswg.org/css-syntax/#parse-list-of-rules
  // 5.3.3. Parse a list of rules
  pub fn ParseListOfRules(d: &EntryData) -> []Rule {
    var p = ParserFromEntryData(d);
    return consumeListOfRules(p, false);
  }

  // https://drafts.csswg.org/css-syntax/#parse-rule
  // 5.3.4. Parse a rule
  pub fn ParseRule(d: &EntryData) -> %Rule {
    var p = ParserFromEntryData(d);

    skipWhitespace(p);

    const rule = switch (nextToken(p)) {
      Token.EOF => null,
      Token.AtRule => return consumeAtRule(p),
      else => return consumeQualifiedRule(p),
    };

    if (rule == null) {
      // TODO: Handle syntax error
    }

    skipWhitespace(p);

    switch (nextToken(p)) {
      Token.EOF => return rule,
      else => return null, // TODO: Handle syntax error
    }
  }

  // https://drafts.csswg.org/css-syntax/#parse-declaration
  // 5.3.5. Parse a declaration
  pub fn ParseDeclaration(d: EntryData) -> %Declaration {
    var p = ParserFromEntryData(d);
    skipWhitespace(p);

    const d = switch (nextToken(p)) {
      Token.Ident => consumeDeclaration(p),
      else => null,
    };

    if (d) {
      return d
    } else {
      // TODO: Handle syntax error
    }
  }

  // https://drafts.csswg.org/css-syntax/#parse-list-of-declarations
  // 5.3.6. Parse a list of declarations
  pub fn ParseListOfDeclarations(d: EntryData) -> []Declaration {
    var p = ParserFromEntryData(d);
    consumeListOfDeclarations(p);
  }

  // https://drafts.csswg.org/css-syntax/#parse-component-value
  // 5.3.7. Parse a component value
  pub fn ParseComponentValue(d: EntryData) -> ComponentValue {
    var p = ParserFromEntryData(d);
    skipWhitespace(p);
    switch (nextToken(p)) {
      Token.EOF => return {}, // TODO: Handle syntax error
    }

    const value = consumeComponentValue(p);
    skipWhitespace(p);
    switch (value) {
      Token.EOF => return value,
      else => return {}, // TODO: Handle syntax error
    }
  }

  // https://drafts.csswg.org/css-syntax/#parse-list-of-component-values
  // 5.3.8. Parse a list of component values
  pub fn ParseListOfComponentValues(d: EntryData) -> []ComponentValue {
    var p = ParserFromEntryData(d);

    const list = []ComponentValue{};
    var cv = consumeComponentValue(p);

    while (cv != Token.EOF) {
      list.append();
      cv = consumeComponentValue(p);
    }
    list;
  }

  //https://drafts.csswg.org/css-syntax/#parse-comma-separated-list-of-component-values
  // 5.3.9. Parse a comma-separated list of component values
  pub fn ParseCommaSeparatedComponentValues(d: EntryData,) -> [][]ComponentValue {
    var p = ParserFromEntryData(d);

    const cvls = [][]ComponentValue{};
    var list = []ComponentValue{};
    var cv: ComponentValue;

    while (true) {
      cv = consumeComponentValue(p);
      switch (cv) {
        Token.EOF => {
          cvls.append(list);
          return cvls;
        },
        Token.Comma => {
          cvls.append(list);
          list = []ComponentValue{};
        },
        else => list.append(cv),
      }
    }
  }



  // https://drafts.csswg.org/css-syntax/#parser-algorithms
  // 5.4. Parser Algorithms

  // The following algorithms comprise the parser. They are called by the parser entry points above.
  //
  // These algorithms may be called with a list of either tokens or of component values. (The difference being that some tokens are replaced by functions and simple blocks in a list of component values.) Similar to how the input stream returned EOF code points to represent when it was empty during the tokenization stage, the lists in this stage must return an <EOF-token> when the next token is requested but they are empty.
  //
  // An algorithm may be invoked with a specific list, in which case it consumes only that list (and when that list is exhausted, it begins returning <EOF-token>s). Otherwise, it is implicitly invoked with the same list as the invoking algorithm.

  // https://drafts.csswg.org/css-syntax/#consume-list-of-rules
  // 5.4.1. Consume a list of rules
  fn consumeListOfRules(p: Parser, top_level: bool) -> []Rule {
    const rules = []Rule{};
    var tok = consumeToken(p);

    while (true) : (tok = consumeToken(p)) {
      switch (tok) {
        Token.Whitespace => {}, // do nothing
        Token.EOF => return rules,

        Token.AtKeyword => {
          reconsume(p);

          // ISSUE: https://github.com/w3c/csswg-drafts/issues/1839
            rules.append(consumeAtRule(p));
        },

        Token.CDO, Token.CDC => if (!top_level) {
          reconsume(p);
          if (consumeQualifiedRule(p)) |qr| {
            rules.append(qr);
          }
        },

        else => {
          reconsume(p);
          if (consumeQualifiedRule(p)) |qr| {
            rules.append(qr);
          }
        },
      }
    }
  }

  // https://drafts.csswg.org/css-syntax/#consume-at-rule
  // 5.4.2. Consume an at-rule
  fn consumeAtRule(p: Parser) -> AtRule {
    var tok = consumeToken(p);
    var ar = AtRule{
      name = tok.data,
      prelude = []ComponentValue{},
      block = null,
    };

    while (true) {
      tok = consumeToken(p);
      switch (tok) {
        Token.Semicolon => return ar,
        Token.EOF => return ar, // TODO: Handle parser error
        Token.LBrace => {
          ar.block = consumeSimpleBlock(p);
          return ar
        },
        ComponentValue.SimpleBlock => |block| {
          ar.block = block;
          return ar
        },
        else => {
          reconsume(p);
          ar.prelude.append(consumeComponentValue(p));
        },
      }
    }
  }

  // https://drafts.csswg.org/css-syntax/#consume-qualified-rule
  // 5.4.3. Consume a qualified rule
  fn consumeQualifiedRule(p: Parser) -> ?QualifiedRule {
    var qr = QualifiedRule{
      prelude = []ComponentValue{},
    };

    var tok = consumeToken(p);
    while (true) : (tok = consumeToken(p)) {
      switch (tok) {
        Token.EOF => return null, // TODO: Handle parse error
        Token.LBrace => {
          qr.block = consumeSimpleBlock(p);
          return qr;
        },
        ComponentValue.SimpleBlock => |block| {
          qr.block = block;
          return qr;
        },
        else => {
          reconsume(p);
          qr.prelude.append(consumeComponentValue(p));
        },
      }
    }
  }

  // https://drafts.csswg.org/css-syntax/#consume-list-of-declarations
  // 5.4.4. Consume a list of declarations
  fn consumeListOfDeclarations(p: Parser) -> []Declaration {
    const list = []Declaration{};

    var tok = consumeToken(p);
    while (true) : (tok = consumeToken(p)) {
      switch (tok) {
        Token.Whitespace, Token.Semicolon => {}, // do nothing
        Token.EOF => return list,

        Token.AtKeyword => {
          reconsume(p);
          list.append(consumeAtRule(p));
        },

        Token.Ident => {
          var temp_list = []Token{tok};
          while (true) {
            switch (nextToken(p)) {
              Token.Semicolon, Token.EOF => {}, // do nothing
              else => {
                temp_list.append(consumeComponentValue(p));
                const d = consumeDeclaration(temp_list);
                if (d) |decl| {
                  list.append(decl);
                }
              }
            }
          }
        },

        else => {
          // TODO: Handle parser error
          reconsume(p);
          while (true) { // Discard until semicolon or end
            switch (nextToken(p)) {
              Token.Semicolon, Token.EOF => break,
              else => consumeComponentValue(p), // discard
            }
          }
        }
      }
    }
  }

  // https://drafts.csswg.org/css-syntax/#consume-declaration
  // 5.4.5. Consume a declaration
  //
  // Note: This algorithm assumes that the next input token has already been checked to be an <ident-token>.
  fn consumeDeclaration(p: Parser) -> ?Declaration {
    const decl = Declaration{
      name = consumeToken(p),
      value = []ComponentValue{},
    };

    skipWhitespace(p);

    var tok = nextToken(p);

    switch (tok) {
      ':' => _ = consumeToken(p),
      else => return null, // TODO: Handle parser error
    }

    tok = nextToken(p);
    while (tok != Token.EOF) : (tok = nextToken(p)) {
      decl.value.append(consumeComponentValue(p));
    }

  // 4. If the last two non-<whitespace-token>s in the declaration’s value are a <delim-token> with the value "!" followed by an <ident-token> with a value that is an ASCII case-insensitive match for "important", remove them from the declaration’s value and set the declaration’s important flag to true.
    var i = decl.value.len-1;
    while ((decl.value[i] %% Token.EOF) == Token.Whitespace) : (i -= 1) {
    }

    switch (decl.value[i] %% Token.EOF) {
      Token.Ident => |ident| if (ident == "important") {// TODO: Case-insensitive
        i -= 1;

        while ((decl.value[i] %% Token.EOF) == Token.Whitespace) : (i -= 1) {
        }

        switch (decl.value[i] %% Token.EOF) {
          Token.Delim => |delim| if (delim == '!') {
            // Though the spec does not instruct to remove whitespace tokens
            // encountered, it's harmless and improves performance and simplicity.
            decl.value = decl.value.slice(0, i); // TODO: Use the proper method
            decl.is_important = true;
          },
        }
      }
    }

    return decl;
  }

  // https://drafts.csswg.org/css-syntax/#consume-component-value
  // 5.4.6. Consume a component value
  fn consumeComponentValue(p: Parser) -> ComponentValue {
    switch (consumeToken(p)) {
      Token.Assoc => |opening| consumeSimpleBlock(p, opening),
      Token.Function => consumeFunction(p),
      Token.Preserved => |tok| ComponentValue.Preserved(tok),
    }
  }

  // https://drafts.csswg.org/css-syntax/#consume-simple-block
  // 5.4.7. Consume a simple block
  //
  // Note: This algorithm assumes that the current input token has already been checked to be an <{-token>, <[-token>, or <(-token>.
  fn consumeSimpleBlock(p: Parser, o: AssocToken) -> ComponentValue.SimpleBlock {
    const ending = getEnding(o);
    const block = ComponentValue.SimpleBlock{
      token = a,
      value = []ComponentValue{},
    };

    while (true) {
      switch (consumeToken(p)) {
        ending => return block,
        Token.EOF => return block, // TODO: Handle parse error
        else => {
          reconsume(p);
          block.value.append(consumeComponentValue(p));
        },
      }
    }
  }

  // https://drafts.csswg.org/css-syntax/#consume-function
  // 5.4.8. Consume a function
  //
  // Note: This algorithm assumes that the current input token has already been checked to be a <function-token>.
  fn consumeFunction(p: Parser, f: Token.Function) -> ComponentValue.Function {
    const fn_cv = ComponentValue.Function{
      name = f,
      value = []ComponentValue{},
    };

    while (true) {
      switch (consumeToken(p)) {
        AssocEnding.RParen => return fn_cv,
        token.EOF => return fn_cv, // TODO: Handle parse error
        else => {
          reconsume(p);
          fn_cv.value.append(consumeComponentValue(p));
        }
      }
    }
  }
}



