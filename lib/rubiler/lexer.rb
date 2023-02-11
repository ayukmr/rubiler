# lexer for transpiler
class Lexer
  attr_accessor :cur_char

  # create lexer
  def initialize(source)
    # source code
    @source = "#{source}\n"

    # current state
    @cur_char = ''
    @cur_pos = -1

    next_char
  end

  # advance to next char
  def next_char
    @cur_pos += 1

    @cur_char =
      if @cur_pos >= @source.length
        # set to \0 if end of file
        "\0"
      else
        @source[@cur_pos]
      end
  end

  # check next char
  def peek
    # return \0 if end of file
    return "\0" if @cur_pos + 1 >= @source.length

    @source[@cur_pos + 1]
  end

  # skip whitespace
  def skip_whitespace
    next_char while @cur_char =~ /[\t\v ]/
  end

  # skip comments
  def skip_comments
    return unless @cur_char == '#'
    next_char while @cur_char != "\n"
  end

  # get next token
  def next_token
    skip_whitespace
    skip_comments

    # get token
    token = general_token
    token ||= operator_token
    token ||= comparison_token
    token ||= special_token

    error("unknown token: #{@cur_char}") unless token

    next_char
    token
  end

  # get current general token
  def general_token
    case @cur_char
    when /[a-zA-Z]/
      start_pos = @cur_pos

      next_char while peek =~ /\w/

      text = @source[start_pos..@cur_pos]
      type = TokenType.keyword(text)

      # keyword or identifier
      Token.new(text, type || TokenType::IDENT)

    when /\d/
      start_pos = @cur_pos

      while peek =~ /\d/
        next_char

        # decimal places
        next unless peek == '.'

        next_char
        error('illegal character in number') if peek !~ /\d/

        next_char while peek =~ /\d/
      end

      text = @source[start_pos..@cur_pos]

      # number literal
      Token.new(text, TokenType::NUMBER)

    when '"'
      next_char
      start_pos = @cur_pos

      next_char until @cur_char == '"'
      text = @source[start_pos..@cur_pos - 1]

      # string literal
      Token.new(text, TokenType::STRING)

    # parentheses
    when '('
      Token.new(@cur_char, TokenType::LPAREN)
    when ')'
      Token.new(@cur_char, TokenType::RPAREN)
    end
  end

  # get current operator token
  def operator_token
    case @cur_char
    # plus
    when '+'
      Token.new(@cur_char, TokenType::PLUS)

    # minus
    when '-'
      Token.new(@cur_char, TokenType::MINUS)

    # asterisk
    when '*'
      Token.new(@cur_char, TokenType::ASTERISK)

    # slash
    when '/'
      Token.new(@cur_char, TokenType::SLASH)
    end
  end

  # get current comparison token
  def comparison_token
    case @cur_char
    when '='
      if peek == '='
        last_char = @cur_char
        next_char

        # equal to
        Token.new("#{last_char}#{@cur_char}", TokenType::EQEQ)
      else
        # equal
        Token.new(@cur_char, TokenType::EQ)
      end

    when '<'
      if peek == '='
        last_char = @cur_char
        next_char

        # less than or equal
        Token.new("#{last_char}#{@cur_char}", TokenType::LTEQ)
      else
        # less than
        Token.new(@cur_char, TokenType::LT)
      end

    when '>'
      if peek == '='
        last_char = @cur_char
        next_char

        # greater than or equal
        Token.new("#{last_char}#{@cur_char}", TokenType::GTEQ)
      else
        # greater than
        Token.new(@cur_char, TokenType::GT)
      end

    when '!'
      if peek == '='
        next_char

        # not equal to
        Token.new("#{last_char}#{@cur_char}", TokenType::NOTEQ)
      else
        error("expected !=, got !#{peek}")
      end
    end
  end

  # get current special token
  def special_token
    case @cur_char
    # newline
    when "\n"
      Token.new(@cur_char, TokenType::NEWLINE)

    # eof
    when "\0"
      Token.new(@cur_char, TokenType::EOF)
    end
  end
end
