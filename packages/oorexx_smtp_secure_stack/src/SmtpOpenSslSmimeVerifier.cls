/* Concrete S/MIME/CMS verifier using the host OpenSSL command provider.
 *
 * SMTP owns no certificates or trust decisions.  OpenSSL verifies the CMS
 * signature and chain against the configured trust file/system store; the
 * signer certificate's RFC822/email identity is projected back as evidence.
 * DKIM is deliberately not accepted as a user message signature.
 */
::class OpenSslSmimeMessageSignatureVerifier subclass SmtpMessageSignatureVerifier public
::method init
  expose openssl trustFile tempRoot sequence
  use strict arg trustFileArg="",tempRootArg="/tmp",opensslArg="openssl"
  openssl=opensslArg~string; trustFile=trustFileArg~string; tempRoot=tempRootArg~string; sequence=0

::method inspect
  expose openssl trustFile tempRoot sequence
  use strict arg message,expectedIdentity=""
  content=message~content
  lower=content~lower
  present=.false
  if lower~pos("application/pkcs7-signature")>0 then present=.true
  if lower~pos("application/x-pkcs7-signature")>0 then present=.true
  if lower~pos("application/pkcs7-mime")>0 then present=.true
  if lower~pos("smime-type=signed-data")>0 then present=.true
  unsupported=.false
  if lower~pos("application/pgp-signature")>0 then unsupported=.true
  if \present then do
    if unsupported then return .SmtpResult~success(.SmtpMessageSignatureEvidence~new(.true,.false,"","","unsupported","PGP signature provider not configured"),"SIGNATURE_UNSUPPORTED")
    return .SmtpResult~success(.SmtpMessageSignatureEvidence~new(.false,.false,"","","","unsigned"),"UNSIGNED")
  end

  sequence+=1
  stem=tempRoot||"/oorexx-smtp-smime-"||sequence||"-"||message~content~length
  input=stem||".eml"; signer=stem||".signer.pem"; verified=stem||".verified"; errors=stem||".err"; meta=stem||".meta"
  call charout input,content
  call stream input,"C","CLOSE"

  cmd=self~q(openssl)||" cms -verify -verify_retcode -in "||self~q(input)||" -signer "||self~q(signer)||" -out "||self~q(verified)
  if trustFile<>"" then cmd||=" -CAfile "||self~q(trustFile)
  cmd||=" > /dev/null 2> "||self~q(errors)
  address system cmd
  cmsRc=rc
  if cmsRc<>0 then do
    detail=self~readSmall(errors)
    self~cleanup(input,signer,verified,errors,meta)
    return .SmtpResult~success(.SmtpMessageSignatureEvidence~new(.true,.false,"","","S/MIME-CMS",detail),"SIGNATURE_INVALID")
  end

  cmd=self~q(openssl)||" x509 -in "||self~q(signer)||" -noout -email -fingerprint -sha256 > "||self~q(meta)||" 2>> "||self~q(errors)
  address system cmd
  xrc=rc
  if xrc<>0 then do
    detail=self~readSmall(errors)
    self~cleanup(input,signer,verified,errors,meta)
    return .SmtpResult~success(.SmtpMessageSignatureEvidence~new(.true,.false,"","","S/MIME-CMS",detail),"SIGNER_CERTIFICATE_INVALID")
  end

  signerIdentity=""; certificateId=""
  do while lines(meta)>0
    line=linein(meta)~strip
    if line="" then iterate
    if line~upper~pos("SHA256 FINGERPRINT=")=1 then certificateId=line~substr(line~pos("=")+1)~space(0)
    else if signerIdentity="" then signerIdentity=line
  end
  call stream meta,"C","CLOSE"

  verifiedFlag=.true; detail="verified"
  if expectedIdentity<>"" then do
    if signerIdentity="" then do
      verifiedFlag=.false; detail="signer identity does not match attributed sender"
    end
    else if \signerIdentity~caselessEquals(expectedIdentity~string) then do
      verifiedFlag=.false; detail="signer identity does not match attributed sender"
    end
  end
  evidence=.SmtpMessageSignatureEvidence~new(.true,verifiedFlag,signerIdentity,certificateId,"S/MIME-CMS",detail)
  self~cleanup(input,signer,verified,errors,meta)
  if verifiedFlag then return .SmtpResult~success(evidence,"SIGNED_VERIFIED")
  return .SmtpResult~success(evidence,"SIGNATURE_IDENTITY_MISMATCH")

::method q private
  use strict arg value
  /* Paths in this provider are package/configuration paths.  Refuse shell
   * metacharacters instead of trying to build a general shell quoting API. */
  value=value~string
  if verify(value,"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./:-")<>0 then raise syntax 88.900 array("Unsafe OpenSSL provider path")
  return '"'||value||'"'

::method readSmall private
  use strict arg path
  if stream(path,"C","QUERY EXISTS")="" then return "OpenSSL verification failed"
  out=""
  do i=1 to 8 while lines(path)>0
    if out<>"" then out||=" | "
    out||=linein(path)~strip
  end
  call stream path,"C","CLOSE"
  return out

::method cleanup private
  use strict arg a,b,c,d,e
  do p over .array~of(a,b,c,d,e)
    if p<>"" then do
      cmd="rm -f "||self~q(p)
      address system cmd
    end
  end
  return .true

::requires "src/SmtpCore.cls"
