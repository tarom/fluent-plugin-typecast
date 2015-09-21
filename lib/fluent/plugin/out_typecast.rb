module Fluent
class TypecastOutput < Output
  Fluent::Plugin.register_output('typecast', self)

  config_param :item_types, default: nil do |value|
    map = value.split(',').map do |type|
      key, type = type.split(/:/)
      if ITEM_TYPES.include?(type)
        [key, type]
      else
        raise ConfigError, "typecast: 'item_types' parameter format is \"KEY:TYPE,...\"\nTYPE is #{ITEM_TYPES.join(', ')}"
      end
    end
    Hash[*map.flatten(1)]
  end
  config_param :time_format, :string, default: nil
  config_param :tag,         :string, default: nil
  config_param :prefix,      :string, default: nil

  ITEM_TYPES = ['json', 'string', 'integer', 'float', 'bool', 'time', 'array']

  def configure(conf)
    super
    raise ConfigError, "typecast: 'prefix' or 'tag' is required" unless @tag or @prefix

    @cast_procs = {}
    @item_types.map {|key, type|
      @cast_procs[key] = cast_proc(type)
    }
  end

  def emit(tag, es, chain)
    tag = 
      if @tag
        @tag
      elsif @prefix
        "#{@prefix}.#{tag}"
      end
    es.each do |time, record|
      record.each_key do |key|
        if cast_proc = @cast_procs[key]
          record[key] = cast_proc.call(record[key])
        end
      end
      router.emit(tag, time, record)
    end
    chain.next
  end

  def cast_proc(key)
    case key
    when 'json'
      Proc.new {|value| value.to_json }
    when 'string'
      Proc.new {|value| value.to_s }
    when 'integer'
      Proc.new {|value| value.to_i }
    when 'float'
      Proc.new {|value| value.to_f }
    when 'bool'
      Proc.new {|value| Config.bool_value(value) }
    when 'time'
      Proc.new {|value| Time.strptime(value, @time_format) }
    when 'array'
      Proc.new {|value| value.split(/\s*,\s*/) }
    else
      Proc.new {|value| value }
    end
  end
end
end
