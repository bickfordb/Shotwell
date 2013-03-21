#import "Signals.h"

void IgnoreSigPIPE(void) {
        // ignore SIGPIPE (or else it will bring our program down if the client
        // closes its socket).
        // NB: if running under gdb, you might need to issue this gdb command:
        //          handle SIGPIPE nostop noprint pass
        //     because, by default, gdb will stop our program execution (which we
        //     might not want).
        struct sigaction sa;

        memset(&sa, 0, sizeof(sa));
        sa.sa_handler = SIG_IGN;

        if (sigemptyset(&sa.sa_mask) < 0 || sigaction(SIGPIPE, &sa, 0) < 0) {
                perror("Could not ignore the SIGPIPE signal");
                exit(EXIT_FAILURE);
        }
}

