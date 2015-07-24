require 'helper'

class TestTypecastOutput < Test::Unit::TestCase

  DEFAULT_CONFIG = %[
    type typecast
  ]

  def setup
    Fluent::Test.setup
  end

  def teardown
  end

  def test_configure
    time_format = "%d/%b/%Y:%H:%M:%S %z"
    tag = "test.tag"
    prefix = "prefix"
    d = create_driver(DEFAULT_CONFIG + %[
      item_types test1:integer,test2:string,test3:time,test4:bool,test5:json
      time_format #{time_format}
      tag #{tag}
      prefix #{prefix}
    ]).instance

    assert_equal('integer', d.item_types['test1'])
    assert_equal('string', d.item_types['test2'])
    assert_equal('time', d.item_types['test3'])
    assert_equal('bool', d.item_types['test4'])
    assert_equal('json', d.item_types['test5'])

    assert_equal(time_format, d.time_format)
    assert_equal(tag, d.tag)
    assert_equal(prefix, d.prefix)
  end

  def test_typecast
    d = create_driver(DEFAULT_CONFIG + %[
      tag test.tag
      item_types i:integer,s:string,t:time,b:bool,a:array,l:long
      time_format %Y-%m-%d %H:%M:%S %z
    ])
    time = Time.parse('2013-02-12 22:01:15 UTC').to_i
    t = '2013-02-12 22:04:14 UTC'
    record = {'i' => '1', 's' => 'foo', 't' => t, 'b' => 'true', 'a' => 'a, b, c', 'o' => 'other', 'l' => '1.1e+1'}
    d.run do
      d.emit(record, time)
    end
    emits = d.emits
    assert_equal 1, emits.length
    tag, time, record = emits[0]
    assert_equal(1, record['i'])
    assert_equal('foo', record['s'])
    assert_equal(Time.gm(2013, 2, 12, 22, 4, 14), record['t'])
    assert_equal(true, record['b'])
    assert_equal(['a', 'b', 'c'], record['a'])
    assert_equal('other', record['o'])
    assert_equal(11, record['l'])
  end

  def test_typecast_float
    d = create_driver(DEFAULT_CONFIG + %[
      tag test.tag
      item_types f:float
    ])
    v = 1.1
    time = Time.parse('2013-02-12 22:01:15 UTC').to_i
    d.run do
      d.emit({'f' => v.to_s }, time)
    end
    record = d.emits[0][2]
    assert_equal(v, record['f'])
  end

  def test_typecast_json
    d = create_driver(DEFAULT_CONFIG + %[
      tag test.tag
      item_types j:json
    ])
    v = {"msg" => "ok"}
    time = Time.parse('2015-01-19 08:35:15 UTC').to_i
    d.run do
      d.emit({'j' => v }, time)
    end
    record = d.emits[0][2]
    assert_equal(v.to_json, record['j'])
  end

  def test_prefix
    d = create_driver(DEFAULT_CONFIG + %[
      item_types i:integer,s:string,t:time,b:bool,a:array
      prefix prefix
    ])
    d.run do
      d.emit({}, Time.now)
    end
    emits = d.emits
    assert_equal 1, emits.length
    tag, time, record = emits[0]
    assert_equal('prefix.test', tag)
  end

  def create_driver(conf = DEFAULT_CONFIG, tag = 'test')
    Fluent::Test::OutputTestDriver.new(Fluent::TypecastOutput, tag).configure(conf)
  end
end
