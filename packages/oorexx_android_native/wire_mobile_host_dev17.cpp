#include <jni.h>
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <stdio.h>
#include <pthread.h>
#include "oorexxapi.h"
static pthread_mutex_t gLock=PTHREAD_MUTEX_INITIALIZER;
static RexxInstance *gInstance=nullptr;
static RexxThreadContext *gContext=nullptr;
static void mark(const char *files,const char *msg){char p[1024];snprintf(p,sizeof(p),"%s/WireOoRexx-startup.log",files);int fd=open(p,O_WRONLY|O_CREAT|O_APPEND,0600);if(fd>=0){dprintf(fd,"NATIVE %s\n",msg);fsync(fd);close(fd);}}
static bool copyAsset(AAssetManager*m,const char*name,const char*out){AAsset*a=AAssetManager_open(m,name,AASSET_MODE_STREAMING);if(!a)return false;int fd=open(out,O_WRONLY|O_CREAT|O_TRUNC,0700);if(fd<0){AAsset_close(a);return false;}char b[32768];int n;bool ok=true;while((n=AAsset_read(a,b,sizeof(b)))>0)if(write(fd,b,(size_t)n)!=n){ok=false;break;}fsync(fd);close(fd);AAsset_close(a);return ok;}
extern "C" JNIEXPORT jint JNICALL Java_org_oorexx_wire_mobile_WireOoRexxRuntime_nativeStart(JNIEnv*env,jobject,jstring je,jstring jf,jobject jam){
 pthread_mutex_lock(&gLock);
 const char*files=env->GetStringUTFChars(jf,nullptr);if(!files){pthread_mutex_unlock(&gLock);return 18;} mark(files,"01 nativeStart entered");
 if(gInstance){mark(files,"02 interpreter already resident");env->ReleaseStringUTFChars(jf,files);pthread_mutex_unlock(&gLock);return 0;}
 const char*entry=env->GetStringUTFChars(je,nullptr);if(!entry){mark(files,"03 entry UTF acquisition FAILED");env->ReleaseStringUTFChars(jf,files);pthread_mutex_unlock(&gLock);return 19;} mark(files,"03 JNI strings acquired");
 AAssetManager*am=AAssetManager_fromJava(env,jam);mark(files,am?"04 AssetManager acquired":"04 AssetManager NULL");
 char d1[1024],d2[1024],program[1200];snprintf(d1,sizeof(d1),"%s/wireapp",files);snprintf(d2,sizeof(d2),"%s/rexx",d1);snprintf(program,sizeof(program),"%s/mobile_main.rex",d2);mkdir(d1,0700);mkdir(d2,0700);mark(files,"05 directories prepared");
 bool copied=am&&copyAsset(am,entry,program);mark(files,copied?"06 Rexx asset copied":"06 Rexx asset copy FAILED");env->ReleaseStringUTFChars(je,entry);if(!copied){env->ReleaseStringUTFChars(jf,files);pthread_mutex_unlock(&gLock);return 20;}
 setenv("REXX_PATH",d2,1);mark(files,"07 REXX_PATH set");
 RexxOption options[1]={{nullptr,nullptr}};mark(files,"08 RexxCreateInterpreter BEGIN");RexxReturnCode rc=RexxCreateInterpreter(&gInstance,&gContext,options);
 char m[256];snprintf(m,sizeof(m),"09 RexxCreateInterpreter RETURN rc=%d instance=%p context=%p",(int)rc,(void*)gInstance,(void*)gContext);mark(files,m);
 if(rc!=0||!gInstance||!gContext){gInstance=nullptr;gContext=nullptr;env->ReleaseStringUTFChars(jf,files);pthread_mutex_unlock(&gLock);return 21;}
 mark(files,"10 NewArray(0) BEGIN");RexxArrayObject args=gContext->NewArray(0);snprintf(m,sizeof(m),"11 NewArray(0) RETURN args=%p",(void*)args);mark(files,m);
 if(args==NULLOBJECT){mark(files,"12 argument array allocation FAILED");env->ReleaseStringUTFChars(jf,files);pthread_mutex_unlock(&gLock);return 22;}
 mark(files,"13 CallProgram BEGIN");RexxObjectPtr result=gContext->CallProgram(program,args);snprintf(m,sizeof(m),"14 CallProgram RETURN result=%p",(void*)result);mark(files,m);
 mark(files,"15 CheckCondition BEGIN");bool condition=gContext->CheckCondition();mark(files,condition?"16 CheckCondition TRUE":"16 CheckCondition FALSE");
 int ret=(result==NULLOBJECT||condition)?23:0;mark(files,ret?"17 nativeStart FAILED":"17 nativeStart SUCCESS");env->ReleaseStringUTFChars(jf,files);pthread_mutex_unlock(&gLock);return ret;
}
extern "C" JNIEXPORT void JNICALL Java_org_oorexx_wire_mobile_WireOoRexxRuntime_nativeActivityDetached(JNIEnv*,jobject){}
