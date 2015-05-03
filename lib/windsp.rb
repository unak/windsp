require 'fiddle/import'

class WinDSP
  module WinMM
    extend Fiddle::Importer
    dlload "winmm.dll"
    extern "int PlaySound(void *, void *, long)"

    SND_SYNC = 0x0000
    SND_ASYNC = 0x0001
    SND_NODEFAULT = 0x0002
    SND_MEMORY = 0x0004
    SND_LOOP = 0x0008
    SND_NOSTOP = 0x0010
    SND_NOWAIT = 0x00002000
    SND_ALIAS = 0x00010000
    SND_ALIAS_ID = 0x00110000
    SND_FILENAME = 0x00020000
    SND_RESOURCE = 0x00040004
    SND_PURGE = 0x0040
    SND_APPLICATION = 0x0080
    SND_SENTRY = 0x00080000
    SND_RING = 0x00100000
    SND_SYSTEM = 0x00200000

    def self.make_wave(pcm)
      head = ["WAVEfmt ", 16, 1, 1, 8000, 8000 * 1 * 1, 1 * 1, 8].pack('a*VvvVVvv')
      data = ["data", pcm.bytesize, pcm].pack('a*Va*')
      ["RIFF", head.bytesize + data.bytesize, head, data].pack('a*Va*a*')
    end

    def self.play_pcm(pcm, sync: true)
      flags = SND_NODEFAULT | SND_MEMORY
      flags |= SND_ASYNC unless sync
      PlaySound(make_wave(pcm), nil, flags)
    end
  end

  VERSION = "0.0.1"

  def self.open(*rest, &block)
    io = self.new(rest)
    if block
      begin
        block.call(io)
      ensure
        io.close
      end
    else
      io
    end
  end

  def initialize(*rest)
    @buf = ""
  end

  def close
    flush
    WinMM.PlaySound(nil, nil, 0)
  end

  def flush
    if @buf.bytesize >= 0
      until WinMM.play_pcm(@buf, sync: false)
        sleep 0.1
      end
    end
    @buf = ""
    WinMM.play_pcm("", sync: true)
  end

  def write(str)
    @buf << str
    flush if @buf.bytesize > 8000 * 1 * 1 * 4
  end

  alias binwrite write
  alias print write
  alias syswrite write
  alias << write
end

module Kernel
  private
  alias windsp_orig_open open
  class << self
    alias windsp_orig_open open
  end
  def open(name, *rest, &block)
    if name == "/dev/dsp"
      WinDSP.open(*rest, &block)
    else
      windsp_orig_open(name, *rest, &block)
    end
  end
  module_function :open
end
