# token for lexer
class Token
  attr_accessor :text, :type

  # create token
  def initialize(text, type)
    # token text
    @text = text

    # token type
    @type = type
  end
end

# types of tokens
module TokenType
  # general
  EOF     = -1
  NEWLINE = 0
  NUMBER  = 1
  IDENT   = 2
  STRING  = 3
  LPAREN  = 4
  RPAREN  = 5

  # keywords
  LABEL = 101
  GOTO  = 102
  PRINT = 103
  INPUT = 104
  LET   = 105
  FN    = 107
  IF    = 108
  WHILE = 109
  ENDS  = 110

  KEYWORDS = {
    label: TokenType::LABEL,
    goto:  TokenType::GOTO,
    print: TokenType::PRINT,
    input: TokenType::INPUT,
    let:   TokenType::LET,
    fn:    TokenType::FN,
    if:    TokenType::IF,
    while: TokenType::WHILE,
    end:   TokenType::ENDS
  }.freeze

  # operators
  EQ       = 201
  PLUS     = 202
  MINUS    = 203
  ASTERISK = 204
  SLASH    = 205
  EQEQ     = 206
  NOTEQ    = 207
  LT       = 208
  LTEQ     = 209
  GT       = 210
  GTEQ     = 211

  class << self
    # convert text to keyword
    def keyword(text)
      KEYWORDS[text.to_sym]
    end
  end
end
