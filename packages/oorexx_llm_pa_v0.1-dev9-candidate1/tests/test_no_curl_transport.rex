parse source . . here
base = filespec("L", here)
path = base || "../src/LlmPaNativeOllama.cls"
text = ""
call stream path, "c", "open read"
do while lines(path) > 0
  text = text || linein(path) || "0a"x
end
call stream path, "c", "close"
/* Comments may say the word curl; executable transport identifiers/commands may not. */
call mustBool text~pos("OpenAICompatCurlTransport") = 0, "no curl provider transport"
call mustBool text~lower~pos("address command") = 0, "no shell command transport"
call mustBool text~lower~pos("address system") = 0, "no system command transport"
call mustBool text~pos(".ApiClient~new") > 0, "API Client owns outbound access"
call mustBool text~pos(".Socket~new") > 0, "RxSock owns loopback HTTP"
say "PASS test_no_curl_transport"
exit 0
mustBool: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 1; end
return
