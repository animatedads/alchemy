#include <mysql.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    MYSQL_RES *res;
    MYSQL_ROW current;
    unsigned long *lengths;
    char *scratch;
    size_t scratch_cap;
} OrxMariaResult;

static int ensure_scratch(OrxMariaResult *r, size_t need) {
    if (need <= r->scratch_cap) return 1;
    size_t cap = r->scratch_cap ? r->scratch_cap : 256;
    while (cap < need) cap *= 2;
    char *p = (char *)realloc(r->scratch, cap);
    if (!p) return 0;
    r->scratch = p;
    r->scratch_cap = cap;
    return 1;
}

unsigned long orx_mariadb_client_version(void) { return mysql_get_client_version(); }

MYSQL *orx_mariadb_connect(const char *host, const char *user, const char *password,
                           const char *database, unsigned int port) {
    MYSQL *m = mysql_init(NULL);
    if (!m) return NULL;
    if (!mysql_real_connect(m, host, user, password, database, port, NULL, 0)) {
        mysql_close(m);
        return NULL;
    }
    return m;
}

void orx_mariadb_close(MYSQL *m) { if (m) mysql_close(m); }
const char *orx_mariadb_error(MYSQL *m) { return m ? mysql_error(m) : "no MYSQL handle"; }
const char *orx_mariadb_sqlstate(MYSQL *m) { return m ? mysql_sqlstate(m) : "08006"; }
const char *orx_mariadb_server_version(MYSQL *m) { return m ? mysql_get_server_info(m) : ""; }

OrxMariaResult *orx_mariadb_query_set(MYSQL *m, const char *sql) {
    if (!m || !sql) return NULL;
    if (mysql_real_query(m, sql, (unsigned long)strlen(sql)) != 0) return NULL;
    MYSQL_RES *res = mysql_store_result(m);
    if (!res) return NULL;
    OrxMariaResult *r = (OrxMariaResult *)calloc(1, sizeof(*r));
    if (!r) { mysql_free_result(res); return NULL; }
    r->res = res;
    return r;
}

void orx_mariadb_result_free(OrxMariaResult *r) {
    if (!r) return;
    if (r->res) mysql_free_result(r->res);
    free(r->scratch);
    free(r);
}

uint64_t orx_mariadb_result_row_count(OrxMariaResult *r) {
    return (r && r->res) ? (uint64_t)mysql_num_rows(r->res) : 0;
}
unsigned int orx_mariadb_result_field_count(OrxMariaResult *r) {
    return (r && r->res) ? mysql_num_fields(r->res) : 0;
}
const char *orx_mariadb_result_field_name(OrxMariaResult *r, unsigned int i) {
    MYSQL_FIELD *f = (r && r->res) ? mysql_fetch_field_direct(r->res, i) : NULL;
    return (f && f->name) ? f->name : "";
}
unsigned int orx_mariadb_result_field_native_type(OrxMariaResult *r, unsigned int i) {
    MYSQL_FIELD *f = (r && r->res) ? mysql_fetch_field_direct(r->res, i) : NULL;
    return f ? (unsigned int)f->type : 0;
}
unsigned long orx_mariadb_result_field_flags(OrxMariaResult *r, unsigned int i) {
    MYSQL_FIELD *f = (r && r->res) ? mysql_fetch_field_direct(r->res, i) : NULL;
    return f ? f->flags : 0;
}

static const char *common_type(const MYSQL_FIELD *f) {
    if (!f) return "UNKNOWN";
    switch (f->type) {
        case MYSQL_TYPE_NULL: return "NULL";
        case MYSQL_TYPE_TINY:
            if (f->length == 1) return "BOOLEAN";
            return "INTEGER";
        case MYSQL_TYPE_SHORT:
        case MYSQL_TYPE_LONG:
        case MYSQL_TYPE_INT24:
        case MYSQL_TYPE_LONGLONG:
        case MYSQL_TYPE_YEAR: return "INTEGER";
        case MYSQL_TYPE_DECIMAL:
        case MYSQL_TYPE_NEWDECIMAL:
        case MYSQL_TYPE_FLOAT:
        case MYSQL_TYPE_DOUBLE: return "DECIMAL";
        case MYSQL_TYPE_DATE:
        case MYSQL_TYPE_NEWDATE: return "DATE";
        case MYSQL_TYPE_TIME:
        case MYSQL_TYPE_TIME2:
        case MYSQL_TYPE_DATETIME:
        case MYSQL_TYPE_DATETIME2:
        case MYSQL_TYPE_TIMESTAMP:
        case MYSQL_TYPE_TIMESTAMP2: return "DATETIME";
#ifdef MYSQL_TYPE_JSON
        case MYSQL_TYPE_JSON: return "JSON";
#endif
        case MYSQL_TYPE_BLOB:
        case MYSQL_TYPE_TINY_BLOB:
        case MYSQL_TYPE_MEDIUM_BLOB:
        case MYSQL_TYPE_LONG_BLOB:
        case MYSQL_TYPE_BIT:
        case MYSQL_TYPE_GEOMETRY:
            return f->charsetnr == 63 ? "BLOB" : "VARCHAR";
        default: return "VARCHAR";
    }
}
const char *orx_mariadb_result_field_common_type(OrxMariaResult *r, unsigned int i) {
    MYSQL_FIELD *f = (r && r->res) ? mysql_fetch_field_direct(r->res, i) : NULL;
    return common_type(f);
}

int orx_mariadb_result_rewind(OrxMariaResult *r) {
    if (!r || !r->res) return 0;
    mysql_data_seek(r->res, 0);
    r->current = NULL;
    r->lengths = NULL;
    return 1;
}
int orx_mariadb_result_next(OrxMariaResult *r) {
    if (!r || !r->res) return 0;
    r->current = mysql_fetch_row(r->res);
    if (!r->current) { r->lengths = NULL; return 0; }
    r->lengths = mysql_fetch_lengths(r->res);
    return r->lengths ? 1 : 0;
}
int orx_mariadb_result_current_is_null(OrxMariaResult *r, unsigned int i) {
    if (!r || !r->current || i >= mysql_num_fields(r->res)) return 1;
    return r->current[i] == NULL;
}

const char *orx_mariadb_result_current_value(OrxMariaResult *r, unsigned int i) {
    if (!r || !r->res || !r->current || !r->lengths || i >= mysql_num_fields(r->res)) return NULL;
    if (!r->current[i]) return NULL;
    MYSQL_FIELD *f = mysql_fetch_field_direct(r->res, i);
    unsigned long len = r->lengths[i];
    if (f && common_type(f)[0] == 'B' && strcmp(common_type(f), "BLOB") == 0) {
        static const char hex[] = "0123456789abcdef";
        size_t need = (size_t)len * 2 + 3;
        if (!ensure_scratch(r, need)) return NULL;
        r->scratch[0] = '\\'; r->scratch[1] = 'x';
        for (unsigned long j = 0; j < len; ++j) {
            unsigned char b = (unsigned char)r->current[i][j];
            r->scratch[2 + j*2] = hex[b >> 4];
            r->scratch[3 + j*2] = hex[b & 15];
        }
        r->scratch[2 + len*2] = 0;
        return r->scratch;
    }
    if (!ensure_scratch(r, (size_t)len + 1)) return NULL;
    memcpy(r->scratch, r->current[i], len);
    r->scratch[len] = 0;
    return r->scratch;
}
