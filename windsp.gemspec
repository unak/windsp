# coding: utf-8
# -*- Ruby -*-
require File.expand_path("lib/windsp")

Gem::Specification.new do |spec|
  spec.name          = "windsp"
  spec.version       = WinDSP::VERSION
  spec.authors       = ["U.Nakamura"]
  spec.email         = ["usa@garbagecollect.jp"]
  spec.description   = %q{`/dev/dsp` emulator for Windows}
  spec.summary       = %q{`/dev/dsp` emulator for Windows}
  spec.homepage      = "https://github.com/unak/windsp"
  spec.license       = "BSD-2-Clause"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
