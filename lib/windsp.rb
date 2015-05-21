require 'fiddle/import'

class WinDSP
  module WinMM
    extend Fiddle::Importer
    dlload "winmm.dll"
    if /64/ =~ RUBY_PLATFORM
      int_ptr = "long long"
    else
      int_ptr = "long"
    end
    extern "int waveOutOpen(void *, #{int_ptr}, void *, #{int_ptr}, #{int_ptr}, long)"
    extern "int waveOutClose(#{int_ptr})"
    extern "int waveOutPrepareHeader(#{int_ptr}, void *, int)"
    extern "int waveOutUnprepareHeader(#{int_ptr}, void *, int)"
    extern "int waveOutWrite(#{int_ptr}, void *, int)"
    extern "int waveOutGetPosition(#{int_ptr}, void *, int)"

    WAVE_FORMAT_PCM = 1
    WAVE_ALLOWSYNC = 0x0002
    WAVE_MAPPED = 0x0004
    WHDR_DONE = 0x00000001
    WHDR_INQUEUE = 0x00000010
  end

  VERSION = "0.0.2"

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

  CHANNELS = 1
  BITS = 8
  FREQUENCY = 8000

  def initialize(*rest)
    tmp = "\0" * 8
    form = [WinMM::WAVE_FORMAT_PCM, CHANNELS, FREQUENCY, rate, (BITS / 8) * CHANNELS, BITS, 0].pack("vvVVvvv")
    ret = WinMM.waveOutOpen(tmp, 0, form, 0, 0, WinMM::WAVE_ALLOWSYNC | WinMM::WAVE_MAPPED)
    raise "cannot open wave device: #{ret}" if ret != 0
    if /64/ =~ RUBY_PLATFORM
      @handle, = tmp.unpack("Q!")
    else
      @handle, = tmp.unpack("L!")
    end
    @buffer = ""
  end

  def close
    flush
    WinMM.waveOutClose(@handle)
  end

  def flush
    if /64/ =~ RUBY_PLATFORM
      x = "Q!"
    else
      x = "L!"
    end
    hdr = [@buffer, @buffer.bytesize, 0, 0, 0, 0, nil, 0].pack("pVV#{x}VVp#{x}")
    @buffer = ""
    ret = WinMM.waveOutPrepareHeader(@handle, hdr, hdr.bytesize)
    raise "error in waveOutPrepareHeader: #{ret}" if ret != 0
    begin
      ret = WinMM.waveOutWrite(@handle, hdr, hdr.bytesize)
      raise "error in waveOutWrite: #{ret}" if ret != 0
      while true
        break if (hdr.unpack("pVV#{x}VVp#{x}")[4] & WinMM::WHDR_DONE) == WinMM::WHDR_DONE
        sleep 0
      end
    ensure
      WinMM.waveOutUnprepareHeader(@handle, hdr, hdr.bytesize)
    end

    self
  end

  BUFFER_FLUSH_SEC = 30
  def write(str)
    @buffer << str
    flush if @buffer.bytesize >= BUFFER_FLUSH_SEC * rate
  end

  def rate
    FREQUENCY * (BITS / 8) * CHANNELS
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

class << IO
  alias windsp_orig_write write
  def write(name, data, offset = nil)
    if name == "/dev/dsp"
      WinDSP.open do |dsp|
        dsp.write(data)
      end
    else
      windsp_orig_binwrite(path, data, offset)
    end
  end

  alias windsp_orig_binwrite binwrite
  def binwrite(name, data, offset = nil)
    if name == "/dev/dsp"
      WinDSP.open do |dsp|
        dsp.binwrite(data)
      end
    else
      windsp_orig_binwrite(path, data, offset)
    end
  end
end
