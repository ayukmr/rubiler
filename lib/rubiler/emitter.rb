# emitter for transpiler
class Emitter
  attr_accessor :scope

  # create emitter
  def initialize(path)
    @path  = path
    @scope = nil

    @header = ''
    @funcs  = ''
    @code   = ''
  end

  # emit text
  def emit(text)
    case @scope
    when EmitScope::HEADER
      # emit to header
      @header += text

    when EmitScope::FUNCS
      # emit to functions
      @funcs += text

    when EmitScope::CODE
      # emit to code
      @code += text
    end
  end

  # emit line of text
  def emit_line(text)
    case @scope
    when EmitScope::HEADER
      # emit to header
      @header += "#{text}\n"

    when EmitScope::FUNCS
      # emit to functions
      @funcs += "#{text}\n"

    when EmitScope::CODE
      # emit to code
      @code += "#{text}\n"
    end
  end

  # set emit scope
  def emit_scope(scope)
    @scope = scope
  end

  # write to file
  def write_file
    File.write(@path, "#{@header}#{@funcs}#{@code}")
  end
end

# scope for emitting lines
module EmitScope
  HEADER = 0
  FUNCS  = 1
  MAIN   = 2
  CODE   = 3
end
