/* NoSQLServer v0.91 SQLite write port.  Native code owns ONLY prepared, transactional
 * file I/O; application SQL, relation selection, and predicates are owned by
 * NoSQLServer. No SQL passed by an application is executed by this port.
 * This component has no persistent SQLite connection and cannot expose SQLite
 * VM results. The output is status/affected count, never database rows. */
#include <oorexxapi.h>
#include <sqlite3.h>
#include <string>
#include <cerrno>
#include <cstdlib>
#include <climits>
#include <cmath>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <cstring>
#include <unordered_set>
#include <mutex>
#include <vector>

static std::string str(RexxMethodContext *ctx, RexxObjectPtr obj) {
    RexxStringObject s = ctx->ObjectToString(obj);
    return std::string(ctx->StringData(s), ctx->StringLength(s));
}
static RexxObjectPtr at(RexxMethodContext *ctx, RexxObjectPtr arr, size_t n) {
    return ctx->ArrayAt((RexxArrayObject)arr, n);
}
static size_t count(RexxMethodContext *ctx, RexxObjectPtr arr) {
    return ctx->ArrayItems((RexxArrayObject)arr);
}
static RexxObjectPtr result(RexxMethodContext *ctx, bool success,
                            const std::string &message, long long affected) {
    RexxDirectoryObject d = ctx->NewDirectory();
    ctx->DirectoryPut(d, ctx->NewStringFromAsciiz(success?"SUCCESS":"FAILED"), "STATUS");
    ctx->DirectoryPut(d, ctx->NewString(message.data(), message.size()), "MESSAGE");
    ctx->DirectoryPut(d, ctx->NewStringFromAsciiz(std::to_string(affected).c_str()), "AFFECTED");
    return d;
}
static bool bindValue(RexxMethodContext *ctx, sqlite3_stmt *stmt, int index,
                      RexxObjectPtr descriptor, std::string &error) {
    if (!descriptor || count(ctx,descriptor)!=2) { error="bad bind descriptor"; return false; }
    const auto type = str(ctx,at(ctx,descriptor,1));
    RexxObjectPtr raw=at(ctx,descriptor,2);
    const auto value = str(ctx,raw);
    int rc=SQLITE_MISUSE;
    if(type=="NULL") rc=sqlite3_bind_null(stmt,index);
    else if(type=="TEXT") rc=sqlite3_bind_text(stmt,index,value.data(),(int)value.size(),SQLITE_TRANSIENT);
    else if(type=="BLOB") rc=sqlite3_bind_blob(stmt,index,value.data(),(int)value.size(),SQLITE_TRANSIENT);
    else if(type=="INTEGER") {
        errno=0; char *end=nullptr;
        const long long number=std::strtoll(value.c_str(),&end,10);
        if(errno==ERANGE || !end || end!=value.c_str()+value.size()) {
            error="INTEGER outside signed 64-bit range or invalid"; return false;
        }
        rc=sqlite3_bind_int64(stmt,index,number);
    }
    else if(type=="DECIMAL") {
        errno=0; char *end=nullptr;
        const double number=std::strtod(value.c_str(),&end);
        if(errno==ERANGE || !std::isfinite(number) || !end || end!=value.c_str()+value.size()) {
            error="invalid finite DECIMAL"; return false;
        }
        rc=sqlite3_bind_double(stmt,index,number);
    }
    else { error="unknown bind type"; return false; }
    if(rc!=SQLITE_OK) {error=sqlite3_errmsg(sqlite3_db_handle(stmt));return false;}
    return true;
}

/* A table-level serializability guard.  The ooRexx executor has already
 * evaluated its predicate against one immutable SQLite backup snapshot.  A
 * native BEGIN IMMEDIATE must precede comparing that exact snapshot with the
 * live table and applying the NoSQLServer-approved mutations.  Comparing all
 * table rows, not merely selected rows, detects inserted phantom matches and
 * prevents stale SELECT ... WHERE decisions from being silently committed.
 *
 * This guard is scoped to single-table UPDATE/DELETE.  It does not claim
 * global transaction isolation or arbitrary external predicate dependencies.
 */
static std::string quotedIdentifier(const std::string &input) {
    std::string quoted="\"";
    for(char c : input) { if(c=='\"') quoted+='\"'; quoted+=c; }
    return quoted+'\"';
}
static bool compareSQLiteCell(sqlite3_stmt *left, sqlite3_stmt *right, int n) {
    const int t=sqlite3_column_type(left,n);
    if(t!=sqlite3_column_type(right,n))return false;
    if(t==SQLITE_NULL)return true;
    if(t==SQLITE_INTEGER)return sqlite3_column_int64(left,n)==sqlite3_column_int64(right,n);
    if(t==SQLITE_FLOAT){
        const double a=sqlite3_column_double(left,n), b=sqlite3_column_double(right,n);
        return std::memcmp(&a,&b,sizeof(double))==0;
    }
    if(t==SQLITE_TEXT || t==SQLITE_BLOB){
        const int size=sqlite3_column_bytes(left,n);
        if(size!=sqlite3_column_bytes(right,n))return false;
        const void *a=t==SQLITE_TEXT?static_cast<const void*>(sqlite3_column_text(left,n)):sqlite3_column_blob(left,n);
        const void *b=t==SQLITE_TEXT?static_cast<const void*>(sqlite3_column_text(right,n)):sqlite3_column_blob(right,n);
        return size==0 || (a && b && std::memcmp(a,b,size)==0);
    }
    return false;
}
static bool compareTable(sqlite3 *oldDb, sqlite3 *liveDb, const std::string &table,
                         std::string &error) {
    if(table.empty() || table.find('\0')!=std::string::npos){error="Invalid table name";return false;}
    /* Stable primary rowid ordering; WITHOUT ROWID tables already fail at
     * the ooRexx writable table contract.  Keep the schema definition exact. */
    sqlite3_stmt *left=nullptr,*right=nullptr;
    const char *schemaSql="SELECT sql FROM sqlite_master WHERE type='table' AND name=?";
    if(sqlite3_prepare_v2(oldDb,schemaSql,-1,&left,nullptr)!=SQLITE_OK ||
       sqlite3_prepare_v2(liveDb,schemaSql,-1,&right,nullptr)!=SQLITE_OK){
        error="Cannot inspect table schema during write validation";
        if(left)sqlite3_finalize(left);
        if(right)sqlite3_finalize(right);
        return false;
    }
    sqlite3_bind_text(left,1,table.data(),(int)table.size(),SQLITE_TRANSIENT);
    sqlite3_bind_text(right,1,table.data(),(int)table.size(),SQLITE_TRANSIENT);
    int a=sqlite3_step(left),b=sqlite3_step(right);
    bool equal=a==SQLITE_ROW && b==SQLITE_ROW && compareSQLiteCell(left,right,0);
    if(equal)equal=sqlite3_step(left)==SQLITE_DONE && sqlite3_step(right)==SQLITE_DONE;
    sqlite3_finalize(left);sqlite3_finalize(right);left=right=nullptr;
    if(!equal){error="Conflicting SQLite table schema since NoSQL snapshot";return false;}
    const auto query="SELECT rowid,* FROM "+quotedIdentifier(table)+" ORDER BY rowid";
    if(sqlite3_prepare_v2(oldDb,query.c_str(),-1,&left,nullptr)!=SQLITE_OK ||
       sqlite3_prepare_v2(liveDb,query.c_str(),-1,&right,nullptr)!=SQLITE_OK){
        error="Cannot validate table rows (unsupported rowid or schema)";
        if(left)sqlite3_finalize(left);
        if(right)sqlite3_finalize(right);
        return false;
    }
    const int cols=sqlite3_column_count(left);
    equal=cols==sqlite3_column_count(right);
    if(equal)for(int i=0;i<cols;i++){
        if(std::strcmp(sqlite3_column_name(left,i),sqlite3_column_name(right,i))!=0){equal=false;break;}
    }
    while(equal){
        a=sqlite3_step(left);b=sqlite3_step(right);
        if(a!=b){equal=false;break;}
        if(a==SQLITE_DONE)break;
        if(a!=SQLITE_ROW){equal=false;break;}
        for(int i=0;i<cols;i++)if(!compareSQLiteCell(left,right,i)){equal=false;break;}
    }
    sqlite3_finalize(left);sqlite3_finalize(right);
    if(!equal)error="Conflicting SQLite table rows since NoSQL snapshot (including phantom rows)";
    return equal;
}
static RexxObjectPtr applyBatch(RexxMethodContext *context,
                                 RexxStringObject path, RexxArrayObject operations,
                                 const std::string &snapshot, const std::string &guardTable) {

    const std::string filename(context->StringData(path),context->StringLength(path));
    if(filename.empty() || filename.find('\0')!=std::string::npos || filename==":memory:")
        return result(context,false,"File-backed SQLite path required",0);
    sqlite3 *db=nullptr;
    int rc=sqlite3_open_v2(filename.c_str(),&db,SQLITE_OPEN_READWRITE|SQLITE_OPEN_NOMUTEX,nullptr);
    if(rc!=SQLITE_OK) {
        auto e=db?std::string(sqlite3_errmsg(db)):"SQLite open failed";
        if(db)sqlite3_close(db);
        return result(context,false,e,0);
    }
    sqlite3_busy_timeout(db,3000);
    sqlite3_stmt *pragma=nullptr;
    rc=sqlite3_prepare_v2(db,"PRAGMA journal_mode",-1,&pragma,nullptr);
    std::string error;
    if(rc!=SQLITE_OK || sqlite3_step(pragma)!=SQLITE_ROW)
        error="Cannot inspect SQLite journal mode";
    /* WAL is supported: every writable-engine read uses a SQLite backup snapshot. */
    if(pragma)sqlite3_finalize(pragma);
    if(error.empty() && sqlite3_exec(db,"PRAGMA foreign_keys=ON; PRAGMA synchronous=FULL; BEGIN IMMEDIATE",nullptr,nullptr,nullptr)!=SQLITE_OK)
        error=sqlite3_errmsg(db);
    if(error.empty() && !guardTable.empty()) {
        sqlite3 *snapshotDb=nullptr;
        if(snapshot.empty() || snapshot.find('\0')!=std::string::npos)
            error="Missing immutable source snapshot for guarded SQLite mutation";
        else {
            rc=sqlite3_open_v2(snapshot.c_str(),&snapshotDb,
                SQLITE_OPEN_READONLY|SQLITE_OPEN_FULLMUTEX,nullptr);
            if(rc!=SQLITE_OK)error="Cannot open immutable snapshot for guarded SQLite mutation";
            else compareTable(snapshotDb,db,guardTable,error);
        }
        if(snapshotDb)sqlite3_close(snapshotDb);
    }
    long long affected=0;
    for(size_t i=1;error.empty() && i<=context->ArrayItems(operations);i++) {
        auto item=context->ArrayAt(operations,i);
        if(!item || count(context,item)!=3){error="Invalid write operation";break;}
        std::string sql=str(context,at(context,item,1));
        auto params=at(context,item,2);
        std::string expectedString=str(context,at(context,item,3));
        long long expected=-1;
        try { expected=std::stoll(expectedString); } catch(...) {error="Invalid expected row count"; break;}
        if(sql.find('\0')!=std::string::npos) {error="SQL contains NUL";break;}
        sqlite3_stmt *stmt=nullptr; const char *tail=nullptr;
        rc=sqlite3_prepare_v2(db,sql.c_str(),-1,&stmt,&tail);
        if(rc!=SQLITE_OK || !stmt){error=sqlite3_errmsg(db); if(stmt) sqlite3_finalize(stmt);break;}
        if(tail && *tail) {error="Multiple SQL statements are forbidden"; sqlite3_finalize(stmt);break;}
        if(sqlite3_stmt_readonly(stmt)) {error="Write port refuses read-only statement"; sqlite3_finalize(stmt); break;}
        if((size_t)sqlite3_bind_parameter_count(stmt)!=count(context,params)) {
            error="Parameter count mismatch";sqlite3_finalize(stmt);break;
        }
        for(size_t j=1;j<=count(context,params);j++)
            if(!bindValue(context,stmt,(int)j,at(context,params,j),error))break;
        if(error.empty()) {
            rc=sqlite3_step(stmt);
            if(rc!=SQLITE_DONE) error=sqlite3_errmsg(db);
            else {
                const auto changed=sqlite3_changes64(db);
                if(expected>=0 && changed!=expected)error="Conflicting or missing row during atomic mutation";
                else affected+=changed;
            }
        }
        sqlite3_finalize(stmt);
    }
    if(error.empty()) {
        if(sqlite3_exec(db,"COMMIT",nullptr,nullptr,nullptr)!=SQLITE_OK)error=sqlite3_errmsg(db);
    }
    if(!error.empty())sqlite3_exec(db,"ROLLBACK",nullptr,nullptr,nullptr);
    sqlite3_close(db);
    return result(context,error.empty(),error,affected);
}
RexxMethod2(RexxObjectPtr, sqliteApplyBatch,
            RexxStringObject, path, RexxArrayObject, operations) {
    return applyBatch(context,path,operations,"","");
}
RexxMethod4(RexxObjectPtr, sqliteApplyBatchGuarded,
            RexxStringObject, path, RexxArrayObject, operations,
            RexxStringObject, snapshot, RexxStringObject, table) {
    return applyBatch(context,path,operations,str(context,snapshot),str(context,table));
}
/* An SQLite-controlled, consistent snapshot protects the ooRexx binary parser
 * from concurrent on-disk changes and incorporates committed WAL frames.
 * The SQL executor still owns all semantics; SQLite's backup API only produces
 * the stable bytes consumed by the existing NoSQL reader.
 * All snapshots are mode 0600 and deletable only when issued by this process.
 * A crashed process can leave an owner-only temporary file; deployments should
 * keep TMPDIR on private local storage and apply their normal stale-file policy.
 */
static std::mutex snapshotMutex;
static std::unordered_set<std::string> issuedSnapshots;

RexxMethod1(RexxObjectPtr, sqliteCreateSnapshot, RexxStringObject, path) {
    const std::string filename(context->StringData(path),context->StringLength(path));
    auto out=result(context,false,"",0);
    if(filename.empty() || filename.find('\0')!=std::string::npos || filename==":memory:") {
        context->DirectoryPut((RexxDirectoryObject)out,context->NewStringFromAsciiz("File-backed SQLite path required"),"MESSAGE");
        return out;
    }
    sqlite3 *source=nullptr,*destination=nullptr;
    int rc=sqlite3_open_v2(filename.c_str(),&source,SQLITE_OPEN_READONLY|SQLITE_OPEN_FULLMUTEX,nullptr);
    std::string error;
    if(rc!=SQLITE_OK)error=source?sqlite3_errmsg(source):"Unable to open snapshot source";
    if(error.empty())sqlite3_busy_timeout(source,3000);
    const char *tmp=getenv("TMPDIR");
    std::string base=(tmp && *tmp)?tmp:"/tmp";
    std::string name=base+"/nosqlserver-snapshot-XXXXXX";
    std::vector<char> buffer(name.begin(),name.end()); buffer.push_back('\0');
    int fd=-1;
    if(error.empty()) {
        fd=mkstemp(buffer.data());
        if(fd<0)error="Cannot create protected SQLite snapshot: "+std::string(strerror(errno));
        else { name=buffer.data(); close(fd); }
    }
    if(error.empty()) {
        rc=sqlite3_open_v2(name.c_str(),&destination,SQLITE_OPEN_READWRITE|SQLITE_OPEN_FULLMUTEX,nullptr);
        if(rc!=SQLITE_OK)error=destination?sqlite3_errmsg(destination):"Cannot open SQLite snapshot destination";
    }
    if(error.empty()) {
        sqlite3_backup *backup=sqlite3_backup_init(destination,"main",source,"main");
        if(!backup)error=sqlite3_errmsg(destination);
        else {
            rc=SQLITE_BUSY;
            for(int tries=0;tries<35;tries++) {
                rc=sqlite3_backup_step(backup,-1);
                if(rc!=SQLITE_BUSY && rc!=SQLITE_LOCKED)break;
                sqlite3_sleep(100);
            }
            int finish=sqlite3_backup_finish(backup);
            if(rc!=SQLITE_DONE || finish!=SQLITE_OK)
                error=std::string("SQLite consistent snapshot failed: ")+sqlite3_errmsg(destination);
        }
    }
    if(destination)sqlite3_close(destination);
    if(source)sqlite3_close(source);
    if(!error.empty()) {
        if(fd>=0)unlink(name.c_str());
        context->DirectoryPut((RexxDirectoryObject)out,context->NewString(error.data(),error.size()),"MESSAGE");
        return out;
    }
    {
        std::lock_guard<std::mutex> lock(snapshotMutex);
        issuedSnapshots.insert(name);
    }
    out=result(context,true,"SQLite snapshot created",0);
    context->DirectoryPut((RexxDirectoryObject)out,context->NewString(name.data(),name.size()),"PATH");
    return out;
}

RexxMethod1(RexxObjectPtr, sqliteDeleteSnapshot, RexxStringObject, path) {
    const std::string filename(context->StringData(path),context->StringLength(path));
    std::lock_guard<std::mutex> lock(snapshotMutex);
    auto it=issuedSnapshots.find(filename);
    if(it==issuedSnapshots.end())return result(context,false,"Unknown or already-released snapshot",0);
    issuedSnapshots.erase(it);
    if(unlink(filename.c_str())!=0)return result(context,false,strerror(errno),0);
    return result(context,true,"",0);
}

/* Bootstrap is explicit and atomic at file-creation time: never truncate an
 * existing database or follow a path symlink. The initial PRAGMA makes a real
 * SQLite header before NoSQLServer's native reader opens the file. */
RexxMethod1(RexxObjectPtr, sqliteCreateFile, RexxStringObject, path) {
    const std::string filename(context->StringData(path),context->StringLength(path));
    if(filename.empty() || filename.find('\0')!=std::string::npos || filename==":memory:")
        return result(context,false,"File-backed SQLite path required",0);
    int fd=::open(filename.c_str(),O_CREAT|O_EXCL|O_WRONLY|O_NOFOLLOW,0600);
    if(fd<0) return result(context,false,"Exclusive create failed: "+std::string(std::strerror(errno)),0);
    ::close(fd);
    sqlite3 *db=nullptr;
    int rc=sqlite3_open_v2(filename.c_str(),&db,SQLITE_OPEN_READWRITE|SQLITE_OPEN_NOMUTEX,nullptr);
    std::string error;
    if(rc!=SQLITE_OK)error=db?sqlite3_errmsg(db):"SQLite open failed";
    else if(sqlite3_exec(db,"PRAGMA page_size=4096; PRAGMA journal_mode=DELETE; PRAGMA user_version=0;",nullptr,nullptr,nullptr)!=SQLITE_OK)
        error=sqlite3_errmsg(db);
    if(db)sqlite3_close(db);
    if(!error.empty())::unlink(filename.c_str());
    return result(context,error.empty(),error,0);
}

RexxMethodEntry methods[]={ REXX_METHOD(sqliteApplyBatch,sqliteApplyBatch), REXX_METHOD(sqliteApplyBatchGuarded,sqliteApplyBatchGuarded), REXX_METHOD(sqliteCreateFile,sqliteCreateFile), REXX_METHOD(sqliteCreateSnapshot,sqliteCreateSnapshot), REXX_METHOD(sqliteDeleteSnapshot,sqliteDeleteSnapshot), REXX_LAST_METHOD() };
RexxPackageEntry NoSQLSQLiteWriter_package_entry={
    STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_0_0,
    "NoSQLSQLiteWriter","0.91.0",nullptr,nullptr,nullptr,methods
};
OOREXX_GET_PACKAGE(NoSQLSQLiteWriter);
