/* Anthropic provider v0.4: Sonnet 5.5 rate card and per-model cache reads.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-03.
 * Figures: platform.claude.com pricing page, 2026-11-03. */
numeric digits 16
cat=.AnthropicModelCatalog~new
s=cat~entry('claude-sonnet-5-5');h=cat~entry('claude-haiku-5-5')
call check s\==.nil,'Sonnet 5.5 registered'
call check s~inputMicroUsdPerMTok=2000000 & s~outputMicroUsdPerMTok=10000000,'Sonnet 5.5 $2/$10 per Mtok'
call check s~cacheReadMultiplier=0.05,'Sonnet 5.5 cache hit 0.05x'
call check h~cacheReadMultiplier=0.1,'Haiku 5.5 cache hit stays 0.1x'
/* 1M of each token kind */
r=.AnthropicMessageReply~new(.true,'','','','claude-sonnet-5-5','end_turn',1000000,1000000,1000000,1000000,0)
call check abs(r~costUsd(cat)-(2+10+2.5+0.10))<1e-9,'Sonnet 5.5 cost: $2 in + $10 out + $2.50 5m write + $0.10 hit'
r=.AnthropicMessageReply~new(.true,'','','','claude-haiku-5-5','end_turn',1000000,1000000,1000000,1000000,0)
call check abs(r~costUsd(cat)-(0.10+0.50+0.125+0.01))<1e-9,'Haiku 5.5 cost unchanged: $0.10+$0.50+$0.125+$0.01'
/* thinking-off serialisation per model */
b=.AnthropicMessageRequest~new('claude-sonnet-5-5','sys',.true,600)~thinkingOff~toBody
call check b['thinking']['type']=='between_tools','Sonnet 5.5 thinking off = between_tools'
b=.AnthropicMessageRequest~new('claude-haiku-5-5','sys',.true,600)~thinkingOff~toBody
call check b['thinking']['type']=='disabled','Haiku 5.5 thinking off = disabled'
say 'PASS anthropic provider v0.4 rates and thinking-off (8 checks)'
exit 0
check: if \arg(1) then do;say 'FAIL:' arg(2);exit 1;end;return
::requires 'AnthropicMessages.cls'
::requires 'AnthropicProvider.cls'
