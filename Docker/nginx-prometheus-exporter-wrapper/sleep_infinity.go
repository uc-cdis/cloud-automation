package main

import "os"
import "os/signal"
import "syscall"

func mainloop() {
    exitSignal := make(chan os.Signal)
    signal.Notify(exitSignal, syscall.SIGINT, syscall.SIGTERM)
    <-exitSignal
}

func main() {
    mainloop()
}
