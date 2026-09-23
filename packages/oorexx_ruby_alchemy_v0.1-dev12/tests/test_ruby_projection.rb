# frozen_string_literal: true
require_relative "../src/ruby/alchemy_rexx"

class FakeEndpoint < Alchemy::Rexx::Endpoint
  attr_reader :calls, :retains, :releases
  def initialize
    @calls = []
    @retains = Hash.new(0)
    @releases = Hash.new(0)
  end
  def retain(h) = @retains[h] += 1
  def release(h) = @releases[h] += 1
  def handles?(_h, name, _private = false) = name == :declared
  def invoke(h, name, args, kwargs, &block)
    @calls << [h, name, args, kwargs, !block.nil?]
    return block.call(args.first) if name == :with_block
    [h, name, args, kwargs]
  end
end

def assert(v, msg)
  raise "FAIL: #{msg}" unless v
end

ep = FakeEndpoint.new
reg = Alchemy::Rexx::IdentityRegistry.new
a = reg.project(ep, 17)
b = reg.project(ep, 17)
assert(a.equal?(b), "identity reversal must intern the projection")
assert(a.respond_to?(:declared), "respond_to_missing? must expose known Rexx messages")

# Crucial rule: invocation does not depend on respond_to?.
assert(!a.respond_to?(:flibble), "fake endpoint deliberately reports flibble absent")
r = a.flibble(42, answer: 99)
assert(r == [17, :flibble, [42], {answer: 99}], "method_missing preserves args/kwargs")

r = a.with_block(6) { |x| x * 7 }
assert(r == 42, "block must cross the projection as a live callable")

assert(reg.release(ep, 17), "release must release live projection")
begin
  a.flibble
  raise "FAIL: released handle invocation should fail"
rescue Alchemy::Rexx::ReleasedHandle
end

c = reg.project(ep, 17)
assert(!c.equal?(a), "released projection must not be resurrected")
puts "PASS ruby projection: identity method_missing kwargs block release"
