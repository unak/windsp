require 'fiddle/import'

class WinDSP
  VERSION = "0.0.4"

  module WinMM
    extend Fiddle::Importer
    dlload "winmm.dll"
    if /64/ =~ RUBY_PLATFORM
      PACK = "Q!"
    else
      PACK = "L!"
    end
    extern "int waveOutOpen(void *, intptr_t, void *, intptr_t, intptr_t, long)"
    extern "int waveOutClose(intptr_t)"
    extern "int waveOutPrepareHeader(intptr_t, void *, int)"
    extern "int waveOutUnprepareHeader(intptr_t, void *, int)"
    extern "int waveOutWrite(intptr_t, void *, int)"
    extern "int waveOutGetPosition(intptr_t, void *, int)"

    WAVE_FORMAT_PCM = 1
    WAVE_ALLOWSYNC = 0x0002
    WAVE_MAPPED = 0x0004
    WHDR_DONE = 0x00000001
    WHDR_INQUEUE = 0x00000010
  end

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
    @handle, = tmp.unpack(WinMM::PACK)
    @hdr = nil
    @buffer = ""
  end

  def close
    flush
    if @hdr
      wait(@hdr)
      WinMM.waveOutUnprepareHeader(@handle, @hdr, @hdr.bytesize)
      @hdr = nil
    end
    WinMM.waveOutClose(@handle)
  end

  def wait(hdr)
    while true
      break if (hdr.unpack("pVV#{WinMM::PACK}VVp#{WinMM::PACK}")[4] & WinMM::WHDR_DONE) == WinMM::WHDR_DONE
      sleep 0
    end
  end

  def flush
    hdr = [@buffer, @buffer.bytesize, 0, 0, 0, 0, nil, 0].pack("pVV#{WinMM::PACK}VVp#{WinMM::PACK}")
    @buffer = ""
    ret = WinMM.waveOutPrepareHeader(@handle, hdr, hdr.bytesize)
    raise "error in waveOutPrepareHeader: #{ret}" if ret != 0
    if @hdr
      wait(@hdr)
      WinMM.waveOutUnprepareHeader(@handle, @hdr, @hdr.bytesize)
      @hdr = nil
    end
    ret = WinMM.waveOutWrite(@handle, hdr, hdr.bytesize)
    raise "error in waveOutWrite: #{ret}" if ret != 0
    @hdr = hdr

    self
  end

  BUFFER_FLUSH_SEC = 4
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
