break malloc_error_break
#break objc_exception_throw
handle SIGPIPE nostop noprint pass
set args "--gtest_catch_exceptions=0"
run
