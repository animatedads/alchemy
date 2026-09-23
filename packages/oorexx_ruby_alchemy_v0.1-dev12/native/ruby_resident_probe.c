#include <ruby.h>
#include <stdio.h>

int main(int argc, char **argv) {
    ruby_sysinit(&argc, &argv);
    RUBY_INIT_STACK;
    ruby_init();
    ruby_init_loadpath();

    int state = 0;
    VALUE result = rb_eval_string_protect(
        "o = Object.new\n"
        "def o.method_missing(n, *a, **k, &b)\n"
        "  [n, a, k, b && b.call(a.first)]\n"
        "end\n"
        "o.flibble(42, answer: 99) { |x| x + 1 }\n", &state);

    if (state) {
        VALUE err = rb_errinfo();
        VALUE msg = rb_obj_as_string(err);
        fprintf(stderr, "ruby exception: %s\n", StringValueCStr(msg));
        ruby_cleanup(state);
        return 2;
    }

    VALUE text = rb_inspect(result);
    printf("%s\n", StringValueCStr(text));
    ruby_cleanup(0);
    return 0;
}
