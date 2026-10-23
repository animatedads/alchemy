/* Native SOAP document/literal XML boundary. libxml2 owns actual XML parsing.
 * This deliberately rejects DTDs, entity references, encodingStyle, nested
 * data graphs and all mustUnderstand headers (no header handlers yet).
 * No XML string parsing is delegated to JSON's XML object mapper.
 */
#include <oorexxapi.h>
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xmlwriter.h>
#include <cstring>
#include <string>
#include <vector>
#include <memory>
#include <limits>

static const char *E11="http://schemas.xmlsoap.org/soap/envelope/";
static const char *E12="http://www.w3.org/2003/05/soap-envelope";
static const char *XSI="http://www.w3.org/2001/XMLSchema-instance";
static const char *XSD="http://www.w3.org/2001/XMLSchema";
static bool equal(const xmlChar *s,const char *v){return s && strcmp((const char*)s,v)==0;}
static bool isElement(xmlNodePtr n,const char *nme,const char *ns){return n&&n->type==XML_ELEMENT_NODE&&equal(n->name,nme)&&((ns[0]==0 && (!n->ns || !n->ns->href)) || (n->ns && equal(n->ns->href,ns)));}
static std::string name(xmlNodePtr n){return n?(const char*)n->name:"";}
static std::string uri(xmlNodePtr n){return n&&n->ns&&n->ns->href?(const char*)n->ns->href:"";}
static bool safeName(const std::string &s){ if(s.empty()||s.size()>120) return false;
  if(!((s[0]>='A'&&s[0]<='Z')||(s[0]>='a'&&s[0]<='z')||s[0]=='_'))return false;
  for(char c:s){if(!((c>='A'&&c<='Z')||(c>='a'&&c<='z')||(c>='0'&&c<='9')||c=='_'||c=='-'||c=='.'))return false;}return true; }
static xmlNodePtr child(xmlNodePtr n,const char *local,const char *ns){for(xmlNodePtr c=n?n->children:nullptr;c;c=c->next)if(isElement(c,local,ns))return c;return nullptr;}
static std::vector<xmlNodePtr> elements(xmlNodePtr n){std::vector<xmlNodePtr> out;for(xmlNodePtr c=n?n->children:nullptr;c;c=c->next)if(c->type==XML_ELEMENT_NODE)out.push_back(c);return out;}
static bool hasUnsafe(xmlNodePtr n,int depth=0){if(depth>20)return true; for(;n;n=n->next){
 if(n->type==XML_ENTITY_REF_NODE||n->type==XML_ENTITY_NODE||n->type==XML_DTD_NODE)return true;
 if(n->type==XML_ELEMENT_NODE){for(xmlAttrPtr a=n->properties;a;a=a->next){
  if(equal(a->name,"encodingStyle"))return true;
  if(a->children&&hasUnsafe(a->children,depth+1))return true;
 } }
 if(n->children&&hasUnsafe(n->children,depth+1))return true;
 }return false; }
static RexxStringObject str(RexxCallContext *c,const std::string &s){return c->String(s.data(),s.size());}
static void put(RexxCallContext *c,RexxDirectoryObject d,const char *key,RexxObjectPtr v){c->DirectoryPut(d,v,key);}
static std::string content(xmlNodePtr node){xmlChar *p=xmlNodeGetContent(node);if(!p)return "";std::string s((char*)p);xmlFree(p);return s;}
static std::string attr(xmlNodePtr node,const char *local,const char *ns){xmlChar *p=xmlGetNsProp(node,(const xmlChar*)local,(const xmlChar*)ns);if(!p)return "";std::string s((char*)p);xmlFree(p);return s;}
static RexxDirectoryObject error(RexxCallContext *c,const std::string &ver,const char *code,const std::string &m){
 auto d=c->NewDirectory();put(c,d,"ok",c->False());put(c,d,"version",str(c,ver));put(c,d,"faultCode",c->String(code));put(c,d,"message",str(c,m));return d;}
static bool scalar(xmlNodePtr n){for(xmlNodePtr c=n->children;c;c=c->next)if(c->type==XML_ELEMENT_NODE)return false;return true;}
static RexxObjectPtr value(RexxCallContext *c,xmlNodePtr n,bool &ok){
 if(!scalar(n)){ok=false;return c->Nil();}
 std::string isnil=attr(n,"nil",XSI);
 if(isnil=="true"||isnil=="1"){
  if(!elements(n).empty() || !content(n).empty()) {ok=false;return c->Nil();}
  return c->Nil();
 }
 std::string type=attr(n,"type",XSI);
 if(type.size()>120){ok=false;return c->Nil();}
 if(!type.empty()){
   size_t pos=type.find(':');
   if(pos==std::string::npos) {ok=false;return c->Nil();}
   const std::string prefix=type.substr(0,pos);
   xmlNsPtr declaration=xmlSearchNs(n->doc,n,(xmlChar*)prefix.c_str());
   if(!declaration || !equal(declaration->href,XSD)) {ok=false;return c->Nil();}
 }
 if(type!="" && type!="xs:string" && type!="xsd:string" && type!="xs:boolean" && type!="xsd:boolean") {ok=false;return c->Nil();}
 if(type=="xsd:boolean"||type=="xs:boolean"){
   auto v=content(n);if(v=="true"||v=="1")return c->True();if(v=="false"||v=="0")return c->False();ok=false;return c->Nil();
 }
 /* Scalar string representation is deliberately lossless: preserve 0007. */
 return str(c,content(n));
}
static std::string normalizedFault(const std::string &v, xmlNodePtr n){
 if(v=="1.1")return content(child(n,"faultcode","")?child(n,"faultcode",""):child(n,"faultcode",E11));
 xmlNodePtr code=child(n,"Code",E12);return content(child(code,"Value",E12));
}
static std::string normalizedReason(const std::string &v, xmlNodePtr n){
 if(v=="1.1")return content(child(n,"faultstring","")?child(n,"faultstring",""):child(n,"faultstring",E11));
 xmlNodePtr reason=child(n,"Reason",E12);return content(child(reason,"Text",E12));
}
RexxRoutine2(RexxObjectPtr,SoapXmlParse,RexxStringObject,input,CSTRING,kind){
 const char *raw=context->StringData(input);
 const size_t len=context->StringLength(input);
 if(memchr(raw,0,len))return error(context,"1.2","Sender","NUL bytes rejected");
 if(len>1048576)return error(context,"1.2","Sender","SOAP frame too large");
 xmlDocPtr doc=xmlReadMemory(raw,(int)len,"soap.xml",nullptr,XML_PARSE_NONET|XML_PARSE_NOERROR|XML_PARSE_NOWARNING|XML_PARSE_COMPACT);
 if(!doc)return error(context,"1.2","Sender","Invalid XML");
 std::unique_ptr<xmlDoc,decltype(&xmlFreeDoc)> owned(doc,xmlFreeDoc);
 if(doc->intSubset||doc->extSubset||hasUnsafe(xmlDocGetRootElement(doc)))return error(context,"1.2","Sender","DTD/entity/encodingStyle unsupported");
 xmlNodePtr root=xmlDocGetRootElement(doc);
 std::string ns=uri(root),ver=ns==E11?"1.1":ns==E12?"1.2":"";
 if(ver.empty()||!isElement(root,"Envelope",ns.c_str()))return error(context,"1.2","VersionMismatch","SOAP Envelope namespace mismatch");
 xmlNodePtr header=child(root,"Header",ns.c_str()),body=child(root,"Body",ns.c_str());
 if(!body)return error(context,ver,"Sender","Missing SOAP Body");
 int countBody=0,countHeader=0;for(auto c:elements(root)){
   if(isElement(c,"Body",ns.c_str()))countBody++;else if(isElement(c,"Header",ns.c_str()))countHeader++;else return error(context,ver,"Sender","Unexpected Envelope child");}
 if(countBody!=1||countHeader>1)return error(context,ver,"Sender","Multiple Header or Body elements");
 if(header){for(auto h:elements(header)){
   std::string mu=attr(h,"mustUnderstand",ns.c_str());
   if(mu=="true"||mu=="1")return error(context,ver,"MustUnderstand","Required SOAP header not supported");
   if(mu!=""&&mu!="false"&&mu!="0")return error(context,ver,"Sender","Invalid mustUnderstand value");
 }}
 auto items=elements(body);if(items.size()!=1)return error(context,ver,"Sender","SOAP Body requires exactly one payload element");
 xmlNodePtr op=items.front();auto result=context->NewDirectory();
 put(context,result,"ok",context->True());put(context,result,"version",str(context,ver));
 put(context,result,"service",str(context,uri(op)));put(context,result,"operation",str(context,name(op)));
 if(isElement(op,"Fault",ns.c_str())){
   put(context,result,"isFault",context->True());
   put(context,result,"faultCode",str(context,normalizedFault(ver,op)));
   put(context,result,"message",str(context,normalizedReason(ver,op)));
   return result;
 }
 put(context,result,"isFault",context->False());
 if(strcmp(kind,"response")==0){
    if(name(op).size()<9||name(op).substr(name(op).size()-8)!="Response")return error(context,ver,"Sender","Expected operation Response");
    auto fields=elements(op);
    if(fields.size()!=1||name(fields[0])!="return")return error(context,ver,"Sender","Expected one return element");
    bool ok=true;auto v=value(context,fields[0],ok);if(!ok)return error(context,ver,"Sender","Complex return value unsupported");
    put(context,result,"result",v);return result;
 }
 if(strcmp(kind,"request")!=0)return error(context,ver,"Sender","Unknown SOAP binding mode");
 if(!safeName(name(op))||uri(op).empty())return error(context,ver,"Sender","Missing operation namespace");
 auto args=context->NewDirectory();int count=0;for(auto e:elements(op)){
  if(++count>64||!safeName(name(e)))return error(context,ver,"Sender","Invalid argument name/count");
  if(context->DirectoryAt(args,name(e).c_str())!=NULLOBJECT)return error(context,ver,"Sender","Duplicate SOAP argument");
  bool ok=true;auto v=value(context,e,ok);if(!ok)return error(context,ver,"Sender","Complex argument unsupported");
  put(context,args,name(e).c_str(),v);
 }
 put(context,result,"arguments",args);return result;
}
static bool start(xmlTextWriterPtr w,const char *ver){
 const char *ns=strcmp(ver,"1.1")==0?E11:E12;
 return xmlTextWriterStartDocument(w,nullptr,"UTF-8",nullptr)>=0&&
 xmlTextWriterStartElementNS(w,(xmlChar*)"soap",(xmlChar*)"Envelope",(xmlChar*)ns)>=0&&
 xmlTextWriterStartElementNS(w,(xmlChar*)"soap",(xmlChar*)"Body",(xmlChar*)ns)>=0;
}
static RexxObjectPtr finish(RexxCallContext *ctx,xmlBufferPtr b,xmlTextWriterPtr w,bool good){
 if(good){if(xmlTextWriterEndElement(w)<0||xmlTextWriterEndElement(w)<0||xmlTextWriterEndDocument(w)<0)good=false;}
 xmlFreeTextWriter(w);RexxObjectPtr o=good?ctx->String((char*)b->content,b->use):ctx->Nil();xmlBufferFree(b);return o;
}
static bool writeValue(RexxCallContext *c,xmlTextWriterPtr w,RexxObjectPtr v){
 if(v==c->Nil()){
   return xmlTextWriterWriteAttributeNS(w,(xmlChar*)"xsi",(xmlChar*)"nil",(xmlChar*)XSI,(xmlChar*)"true")>=0;
 }
 if(v==c->True()||v==c->False()){
  if(xmlTextWriterWriteAttribute(w,(xmlChar*)"xmlns:xs",(const xmlChar*)XSD)<0 ||
     xmlTextWriterWriteAttributeNS(w,(xmlChar*)"xsi",(xmlChar*)"type",(xmlChar*)XSI,(xmlChar*)"xs:boolean")<0)return false;
  return xmlTextWriterWriteString(w,(xmlChar*)(v==c->True()?"true":"false"))>=0;
 }
 if(c->IsArray(v)||c->IsDirectory(v)||!c->IsString(v))return false;
 auto s=c->ObjectToString(v);
 const char *bytes=c->StringData(s);
 const size_t len=c->StringLength(s);
 for(size_t i=0;i<len;++i){unsigned char ch=(unsigned char)bytes[i];if(ch==0 || (ch<32 && ch!=9 && ch!=10 && ch!=13))return false;}
 if(!xmlCheckUTF8((xmlChar*)bytes))return false;
 return xmlTextWriterWriteString(w,(const xmlChar*)bytes)>=0;
}
static RexxObjectPtr build(RexxCallContext *ctx,const char *kind,const char *ver,const char *ns,const char *operation,RexxObjectPtr payload){
 if(strcmp(ver,"1.1")&&strcmp(ver,"1.2"))return ctx->Nil();
 if(!safeName(operation)||strlen(ns)>500||strlen(ns)==0)return ctx->Nil();
 xmlBufferPtr b=xmlBufferCreate();if(!b)return ctx->Nil();xmlTextWriterPtr w=xmlNewTextWriterMemory(b,0);if(!w){xmlBufferFree(b);return ctx->Nil();}
 bool good=start(w,ver);
 std::string wrapper(operation);
 if(strcmp(kind,"response")==0)wrapper+="Response";
 if(good)good=xmlTextWriterStartElementNS(w,(xmlChar*)"m",(xmlChar*)wrapper.c_str(),(xmlChar*)ns)>=0;
 if(good&&strcmp(kind,"request")==0){
   if(!ctx->IsDirectory(payload))good=false;
   else{
     RexxObjectPtr indexes=ctx->SendMessage0(payload,"ALLINDEXES");
     if(!ctx->IsArray(indexes)||ctx->ArrayItems((RexxArrayObject)indexes)>64)good=false;
     else for(size_t i=1;good&&i<=ctx->ArrayItems((RexxArrayObject)indexes);++i){
       auto keyObject=ctx->ArrayAt((RexxArrayObject)indexes,i);
       const char *key=ctx->CString(keyObject);
       if(ctx->StringLength(ctx->ObjectToString(keyObject))!=strlen(key) || !safeName(key)) {good=false;break;}
       RexxObjectPtr v=ctx->DirectoryAt((RexxDirectoryObject)payload,key);
       if(ctx->IsDirectory(v)||ctx->IsArray(v)){good=false;break;}
       good=xmlTextWriterStartElement(w,(const xmlChar*)key)>=0&&writeValue(ctx,w,v)&&xmlTextWriterEndElement(w)>=0;
     }
   }
 }else if(good){good=xmlTextWriterStartElement(w,(xmlChar*)"return")>=0&&writeValue(ctx,w,payload)&&xmlTextWriterEndElement(w)>=0;}
 if(good)good=xmlTextWriterEndElement(w)>=0;
 return finish(ctx,b,w,good);
}
RexxRoutine4(RexxObjectPtr,SoapXmlBuildRequest,CSTRING,ver,CSTRING,service,CSTRING,operation,RexxObjectPtr,args){
 return build(context,"request",ver,service,operation,args);
}
RexxRoutine4(RexxObjectPtr,SoapXmlBuildResponse,CSTRING,ver,CSTRING,service,CSTRING,operation,RexxObjectPtr,value){
 return build(context,"response",ver,service,operation,value);
}
RexxRoutine3(RexxObjectPtr,SoapXmlBuildFault,CSTRING,ver,CSTRING,code,CSTRING,reason){
 if(strcmp(ver,"1.1")&&strcmp(ver,"1.2"))ver="1.2";
 xmlBufferPtr b=xmlBufferCreate();if(!b)return context->Nil();xmlTextWriterPtr w=xmlNewTextWriterMemory(b,0);if(!w){xmlBufferFree(b);return context->Nil();}
 bool good=start(w,ver);const char *ns=strcmp(ver,"1.1")==0?E11:E12;
 if(good)good=xmlTextWriterStartElementNS(w,(xmlChar*)"soap",(xmlChar*)"Fault",(xmlChar*)ns)>=0;
 if(good&&strcmp(ver,"1.1")==0){
  std::string fc=std::string("soap:")+(strcmp(code,"Sender")==0?"Client":strcmp(code,"Receiver")==0?"Server":code);
  good=xmlTextWriterWriteElement(w,(xmlChar*)"faultcode",(xmlChar*)fc.c_str())>=0&&xmlTextWriterWriteElement(w,(xmlChar*)"faultstring",(xmlChar*)reason)>=0;
 }else if(good){
  std::string fc=std::string("soap:")+code;
  good=xmlTextWriterStartElementNS(w,(xmlChar*)"soap",(xmlChar*)"Code",(xmlChar*)ns)>=0&&
   xmlTextWriterWriteElementNS(w,(xmlChar*)"soap",(xmlChar*)"Value",(xmlChar*)ns,(xmlChar*)fc.c_str())>=0&&xmlTextWriterEndElement(w)>=0&&
   xmlTextWriterStartElementNS(w,(xmlChar*)"soap",(xmlChar*)"Reason",(xmlChar*)ns)>=0&&
   xmlTextWriterStartElementNS(w,(xmlChar*)"soap",(xmlChar*)"Text",(xmlChar*)ns)>=0&&
   xmlTextWriterWriteAttribute(w,(xmlChar*)"xml:lang",(xmlChar*)"en")>=0&&
   xmlTextWriterWriteString(w,(xmlChar*)reason)>=0&&xmlTextWriterEndElement(w)>=0&&xmlTextWriterEndElement(w)>=0;
 }
 if(good)good=xmlTextWriterEndElement(w)>=0;
 return finish(context,b,w,good);
}
RexxRoutineEntry routines[]={REXX_TYPED_ROUTINE(SoapXmlParse,SoapXmlParse),REXX_TYPED_ROUTINE(SoapXmlBuildRequest,SoapXmlBuildRequest),REXX_TYPED_ROUTINE(SoapXmlBuildResponse,SoapXmlBuildResponse),REXX_TYPED_ROUTINE(SoapXmlBuildFault,SoapXmlBuildFault),REXX_LAST_ROUTINE()};
RexxPackageEntry SoapXml_package_entry={STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_0_0,"SoapXml","0.1.0",NULL,NULL,routines,NULL};
OOREXX_GET_PACKAGE(SoapXml);
