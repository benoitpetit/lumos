/*
 * Lumos Package Stub
 * A minimal statically-linked Lua interpreter that loads an appended Lua payload.
 *
 * Build with: musl-gcc -static -O2 stub.c -o lumos-stub-linux-x86_64 \
 *             /usr/lib/x86_64-linux-gnu/liblua5.3.a -lm -I/usr/include/lua5.3
 */

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#elif __APPLE__
#include <mach-o/dyld.h>
#else
#include <unistd.h>
#endif

static int get_self_path(char *out, size_t out_len) {
#ifdef _WIN32
    DWORD len = GetModuleFileNameA(NULL, out, (DWORD)out_len);
    return (len > 0 && len < out_len) ? 0 : -1;
#elif __APPLE__
    uint32_t len = (uint32_t)out_len;
    return _NSGetExecutablePath(out, &len);
#else
    ssize_t len = readlink("/proc/self/exe", out, out_len - 1);
    if (len != -1) {
        out[len] = '\0';
        return 0;
    }
    return -1;
#endif
}

static unsigned long long read_u64_le(const unsigned char *p) {
    return ((unsigned long long)p[0])
         | ((unsigned long long)p[1] << 8)
         | ((unsigned long long)p[2] << 16)
         | ((unsigned long long)p[3] << 24)
         | ((unsigned long long)p[4] << 32)
         | ((unsigned long long)p[5] << 40)
         | ((unsigned long long)p[6] << 48)
         | ((unsigned long long)p[7] << 56);
}

int main(int argc, char *argv[]) {
    char self_path[4096];
    if (get_self_path(self_path, sizeof(self_path)) != 0) {
        fprintf(stderr, "Error: cannot determine executable path\n");
        return 1;
    }

    FILE *f = fopen(self_path, "rb");
    if (!f) {
        fprintf(stderr, "Error: cannot open executable: %s\n", self_path);
        return 1;
    }

    if (fseek(f, -8, SEEK_END) != 0) {
        fprintf(stderr, "Error: cannot seek in executable\n");
        fclose(f);
        return 1;
    }

    unsigned char size_buf[8];
    if (fread(size_buf, 1, 8, f) != 8) {
        fprintf(stderr, "Error: cannot read payload size footer\n");
        fclose(f);
        return 1;
    }

    unsigned long long payload_size = read_u64_le(size_buf);
    if (payload_size == 0 || payload_size > 100 * 1024 * 1024) {
        fprintf(stderr, "Error: invalid payload size (%llu)\n", payload_size);
        fclose(f);
        return 1;
    }

    if (fseek(f, -(long long)(8 + payload_size), SEEK_END) != 0) {
        fprintf(stderr, "Error: cannot seek to payload offset\n");
        fclose(f);
        return 1;
    }

    unsigned char *payload = (unsigned char *)malloc((size_t)payload_size);
    if (!payload) {
        fprintf(stderr, "Error: cannot allocate memory for payload\n");
        fclose(f);
        return 1;
    }

    if (fread(payload, 1, (size_t)payload_size, f) != payload_size) {
        fprintf(stderr, "Error: cannot read payload\n");
        free(payload);
        fclose(f);
        return 1;
    }
    fclose(f);

    lua_State *L = luaL_newstate();
    if (!L) {
        fprintf(stderr, "Error: cannot create Lua state\n");
        free(payload);
        return 1;
    }
    luaL_openlibs(L);

    /* Set global arg table */
    lua_createtable(L, argc, 0);
    int i;
    for (i = 0; i < argc; i++) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setglobal(L, "arg");

    if (luaL_loadbuffer(L, (const char *)payload, (size_t)payload_size, "@lumos_package") != LUA_OK) {
        fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));
        free(payload);
        lua_close(L);
        return 1;
    }

    free(payload);

    if (lua_pcall(L, 0, LUA_MULTRET, 0) != LUA_OK) {
        fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));
        lua_close(L);
        return 1;
    }

    lua_close(L);
    return 0;
}
