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

  ITEM_TYPES = ['string', 'integer', 'bool', 'time', 'array']

  def configure(conf)
    super
    raise ConfigError, "typecast: 'prefix' or 'tag' is required" unless @tag or @prefix
  end

  def emit(tag, es, chain)
    tag = 
      if @tag
        @tag
      elsif @prefix
        "#{@prefix}.#{tag}"
      end
    es.each do |time, record|
      record.keys.each do |key|
        record[key] = cast(key, record[key])
      end
      Fluent::Engine.emit(tag, time, record)
    end
    chain.next
  end

  def cast(key, value)
    case @item_types[key]
    when 'string'
      value.to_s
    when 'integer'
      value.to_i
    when 'bool'
      Config.bool_value(value)
    when 'time'
      Time.strptime(value, @time_format)
    when 'array'
      value.split(/\s*,\s*/)
    else
      value
    end
  end
end
end
