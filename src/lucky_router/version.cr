module LuckyRouter
  # The current LuckyRouter version is defined in `shard.yml`
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
end
