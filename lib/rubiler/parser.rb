# parser for transpiler
class Parser
  # create parser
  def initialize(lexer, emitter)
    # transpiler elements
    @lexer   = lexer
    @emitter = emitter

    # keep track of state
    @cur_func        = 'main'
    @symbols         = { 'main' => Set.new }
    @functions       = Set.new
    @labels_declared = Set.new
    @labels_gone_to  = Set.new

    # initialize current and peek tokens
    next_token
    next_token
  end

  # check if current token matches
  def token?(type)
    @cur_token.type == type
  end

  # check if next token matches
  def peek?(type)
    @peek_token.type == type
  end

  # try to match current token
  def match(type)
    # match type to current token's type
    error("expected #{type}, got #{@cur_token.type}") unless token?(type)
    next_token
  end

  # advance to next token
  def next_token
    @cur_token = @peek_token
    @peek_token = @lexer.next_token
  end

  # program ::= {statement}
  def program
    @emitter.emit_scope(EmitScope::HEADER)
    @emitter.emit_line('#include <stdio.h>')

    @emitter.emit_scope(EmitScope::CODE)
    @emitter.emit_line('int main() {')

    # skip excess newlines
    next_token while token?(TokenType::NEWLINE)

    # parse statements in program
    statement until token?(TokenType::EOF)

    @emitter.emit_line('return 0;')
    @emitter.emit_line('}')

    # check that each label gone to is declared
    @labels_gone_to.each do |label|
      error("attempting to go to undeclared label: #{label}") unless @labels_declared.include?(label)
    end
  end

  # {statement}
  def statement
    # invalid token
    error("invalid statement at '#{@cur_token.text}'") unless valid_statement?

    action_statement
    block_statement
    label_statement
    assignment_statement

    nl
  end

  # check if current token type is valid statement
  def valid_statement?
    @cur_token.type == TokenType::IDENT   ||
      @cur_token.type == TokenType::LABEL ||
      @cur_token.type == TokenType::GOTO  ||
      @cur_token.type == TokenType::PRINT ||
      @cur_token.type == TokenType::INPUT ||
      @cur_token.type == TokenType::LET   ||
      @cur_token.type == TokenType::FN    ||
      @cur_token.type == TokenType::IF    ||
      @cur_token.type == TokenType::WHILE
  end

  # process action statement
  def action_statement
    case @cur_token.type
    # "print" (expression | string)?
    when TokenType::PRINT
      next_token

      # expression or string
      if token?(TokenType::STRING)
        @emitter.emit_line("printf(\"%s\\n\", \"#{@cur_token.text}\");")
        next_token
      else
        @emitter.emit('printf("%.2f\n", (float) (')
        expression

        @emitter.emit_line('));')
      end

    # call ident
    when TokenType::IDENT
      error("function does not exist: #{@cur_token.text}") unless @functions.include?(@cur_token.text)

      @emitter.emit_line("#{@cur_token.text}();")
      next_token
    end
  end

  # process block statement
  def block_statement
    case @cur_token.type
    # "fn" ident nl {statement} "end" nl
    when TokenType::FN
      error('cannot create function in function') if @emitter.scope == EmitScope::FUNCS
      next_token

      # make sure label doesn't already exist
      error("function already exists: #{@cur_token.text}") if @functions.include?(@cur_token.text)
      @functions.add(@cur_token.text)

      @cur_func = @cur_token.text
      @symbols[@cur_func] = Set.new

      @emitter.emit_scope(EmitScope::FUNCS)
      @emitter.emit_line("void #{@cur_token.text}() {")

      match(TokenType::IDENT)
      nl

      # zero or more statements in body
      statement until token?(TokenType::ENDS)
      match(TokenType::ENDS)

      @emitter.emit_line('}')
      @emitter.emit_scope(EmitScope::CODE)

      @cur_func = 'main'

    # "if" "(" comparison ")" nl {statement} "end" nl
    when TokenType::IF
      next_token

      match(TokenType::LPAREN)
      @emitter.emit('if (')

      comparison

      match(TokenType::RPAREN)
      @emitter.emit_line(') {')

      nl

      # zero or more statements in body
      statement until token?(TokenType::ENDS)
      match(TokenType::ENDS)

      @emitter.emit_line('}')

    # "while" "(" comparison ")" nl {statement} "end" nl
    when TokenType::WHILE
      next_token

      match(TokenType::LPAREN)
      @emitter.emit('while (')

      comparison

      match(TokenType::RPAREN)
      @emitter.emit_line(') {')

      nl

      # zero or more statements in body
      statement until token?(TokenType::ENDS)
      match(TokenType::ENDS)

      @emitter.emit_line('}')
    end
  end

  # process label statement
  def label_statement
    case @cur_token.type
    # "label" ident nl
    when TokenType::LABEL
      next_token

      # make sure label doesn't already exist
      error("label already exists: #{@cur_token.text}") if @labels_declared.include?(@cur_token.text)
      @labels_declared.add(@cur_token.text)

      @emitter.emit_line("#{@cur_token.text}:")
      match(TokenType::IDENT)

    # "goto" ident nl
    when TokenType::GOTO
      next_token
      @labels_gone_to.add(@cur_token.text)

      @emitter.emit_line("goto #{@cur_token.text};")
      match(TokenType::IDENT)
    end
  end

  # process assignment statement
  def assignment_statement
    case @cur_token.type
    # "let" ident "=" expression nl
    when TokenType::LET
      next_token

      unless @symbols[@cur_func].include?(@cur_token.text)
        # add ident to symbols if it doesn't exist
        @symbols[@cur_func].add(@cur_token.text)
        @emitter.emit_line("float #{@cur_token.text};")
      end

      @emitter.emit("#{@cur_token.text} = ")

      match(TokenType::IDENT)
      match(TokenType::EQ)

      expression
      @emitter.emit_line(';')

    # "input" ident nl
    when TokenType::INPUT
      next_token

      unless @symbols[@cur_func].include?(@cur_token.text)
        # add ident to symbols if it doesn't exist
        @symbols[@cur_func].add(@cur_token.text)
        @emitter.emit_line("float #{@cur_token.text};")
      end

      @emitter.emit_line("if (0 == scanf(\"%f\", &#{@cur_token.text})) {")

      @emitter.emit_line("#{@cur_token.text} = 0;")
      @emitter.emit_line('scanf("%*s");')

      @emitter.emit_line('}')

      match(TokenType::IDENT)
    end
  end

  # nl ::= '\n'+
  def nl
    match(TokenType::NEWLINE)
    next_token while token?(TokenType::NEWLINE)
  end

  # comparison ::= expression (("==" | "!=" | ">" | ">=" | "<" | "<=") expression)+
  def comparison
    expression

    # require at least one comparison operator and expression
    if comparison_operator?
      @emitter.emit(@cur_token.text)

      next_token
      expression
    end

    # can have zero or more comparison operator and expressions
    while comparison_operator?
      @emitter.emit(@cur_token.text)

      next_token
      expression
    end
  end

  # check if current token is a comparison operator
  def comparison_operator?
    token?(TokenType::EQEQ)    ||
      token?(TokenType::NOTEQ) ||
      token?(TokenType::GT)    ||
      token?(TokenType::GTEQ)  ||
      token?(TokenType::LT)    ||
      token?(TokenType::LTEQ)
  end

  # expression ::= term {("+" | "-") term}
  def expression
    term

    # can have zero or more +/- and terms
    while token?(TokenType::PLUS) || token?(TokenType::MINUS)
      @emitter.emit(@cur_token.text)

      next_token
      term
    end
  end

  # term ::= unary {("*" | "/") unary}
  def term
    unary

    # can have zero or more *// and unaries
    while token?(TokenType::ASTERISK) || token?(TokenType::SLASH)
      @emitter.emit(@cur_token.text)

      next_token
      unary
    end
  end

  # unary ::= ["+" | "-"] primary
  def unary
    # optional unary +/-
    if token?(TokenType::PLUS) || token?(TokenType::MINUS)
      @emitter.emit(@cur_token.text)
      next_token
    end

    primary
  end

  # primary ::= number | ident
  def primary
    case @cur_token.type
    when TokenType::NUMBER
      @emitter.emit(@cur_token.text)
      next_token

    when TokenType::IDENT
      # ensure variable exists
      unless @symbols[@cur_func].include?(@cur_token.text)
        error("referencing variable before assignment: #{@cur_token.text}")
      end

      @emitter.emit(@cur_token.text)
      next_token

    else
      error("unexpected token at #{@cur_token.text}")
    end
  end
end
