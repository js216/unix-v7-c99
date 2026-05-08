void putchar(char ch)
{
    long ret;

    // syscall numbers for x86_64 Linux:
    // write = 1
    // fd 1 = stdout
    __asm__ volatile (
        "syscall"
        : "=a"(ret)                  // output: return value in rax
        : "a"(1),                    // rax = syscall number 1 (write)
          "D"(1),                    // rdi = fd 1 (stdout)
          "S"(&ch),                  // rsi = pointer to buffer
          "d"(1)                     // rdx = length 1
        : "rcx", "r11", "memory"
    );

    return (ret == 1) ? c : -1;
}
