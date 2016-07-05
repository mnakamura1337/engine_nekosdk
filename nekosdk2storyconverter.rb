# coding: utf-8
require_relative 'nekosdk_advscript2'

require_relative 'converter_common'

class Nekosdk2StoryConverter
  include ImplicitChars
  include DetectQuotes

  def initialize(fn, meta, lang)
    @meta = meta
    @lang = lang

    @scr = NekosdkAdvscript2.from_file(fn)
    @id_to_idx = []
    @scr.nodes.each_with_index { |n, idx|
      @id_to_idx[n.id] = idx
    }

    @out = []
    @imgs = {}
    @chars = {}
  end

  def out
    {
      'meta' => @meta,
      'imgs' => @imgs,
      'chars' => @chars,
      'script' => @out,
    }
  end

  def run
    i = 0
    loop {
      n = @scr.nodes[i]
      process_node(n)
      i = @id_to_idx[n.next_id]
      return if i.nil?
    }
  end

  def process_node(n)
    case n.opcode
    when 5
      process_text_display(n)
    when 10 # [背景ロード]
      process_bg_load(n)
    when 30 # [ＢＧＭ再生]
      process_bgm_start(n)
    when 31 # [ＢＧＭ停止]
      process_bgm_stop(n)
    else
      puts "#{n.id}. type1=#{n.type1} opcode=#{n.opcode} some_ofs=#{n.some_ofs} next_id=#{n.next_id}"
      n.strs.each_with_index { |s, i|
        ss = s.value.rstrip
        puts "  s#{i}: #{ss.encode('UTF-8')}" unless ss.empty?
      }
      puts
    end
  end

  def process_text_display(n)
    s = strs(n)
    #cmd = s[0]
    char = s[1]
    txt = s[2]
    voice_fn = s[3].gsub(/\\/, '/')

    h = {
      'txt' => {@lang => txt},
    }

    if char.empty?
      h['op'] = 'narrate'
    else
      op, msg = detect_quotes(txt, true)
      h['op'] = op
      h['txt'] = {@lang => msg}
      h['char'] = get_char_by_name(char)
    end
    h['voice'] = voice_fn unless voice_fn.empty?

    @out << h

    @out << {'op' => 'keypress'}
  end

  # [ＢＧＭ再生] bgm\M01-m.ogg
  # ch:0/vol:40/pos:0/tm:3500
  def process_bgm_start(n)
    s = strs(n)
    params = parse_cmd(s[0], '[ＢＧＭ再生]')

    # TODO: vol, pos, tm
    @out << {
      'op' => 'sound_play',
      'fn' => convert_fn(s[1]),
      'channel' => "music#{params['ch']}",
    }
  end

  # [ＢＧＭ停止]
  # ch:1 / tm:2500
  def process_bgm_stop(n)
    s = strs(n)
    params = parse_cmd(s[0], '[ＢＧＭ停止]')

    # TODO: support "tm"
    @out << {
      'op' => 'sound_stop',
      'channel' => "music#{params['ch']}",
    }
  end

  # [背景ロード]
  def process_bg_load(n)
    s = strs(n)
    @out << {
      'op' => 'img',
      'layer' => 'bg',
      'fn' => convert_fn(s[1])
    }
  end

  def strs(n)
    n.strs.map { |s| s.value.rstrip.encode('UTF-8') }
  end

  def parse_cmd(cmd, expect_keyword)
    lines = cmd.split(/\n/)
    raise "invalid line 0: #{lines[0].inspect}" unless lines[0][0, expect_keyword.length] == expect_keyword

    r = {}
    lines[1..-1].each { |line|
      line.split(/\//).each { |kv_pair|
        k, v = kv_pair.strip.split(/:/)
        r[k] = v
      }
    }

    return r
  end

  def convert_fn(fn)
    fn.gsub(/\\/, '/').downcase.gsub(/\.bmp$/, '.png')
  end
end
