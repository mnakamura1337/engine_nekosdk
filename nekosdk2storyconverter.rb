require_relative 'nekosdk_advscript2'

require_relative 'converter_common'

class Nekosdk2StoryConverter
  include ImplicitChars

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
    puts "#{n.id}. type1=#{n.type1} type2=#{n.type2} some_ofs=#{n.some_ofs} next_id=#{n.next_id}"

    n.strs.each_with_index { |s, i|
      ss = s.value.rstrip
      puts "  s#{i}: #{ss.encode('UTF-8')}" unless ss.empty?
    }

    puts
  end
end
