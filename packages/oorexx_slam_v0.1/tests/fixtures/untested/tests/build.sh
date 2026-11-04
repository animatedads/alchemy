#!/bin/sh
# Untested-report fixture: builds the helper (this comment names helperNever, which must not count).
g++ -o helper ../native/helper.cpp && ./helper helperUser
