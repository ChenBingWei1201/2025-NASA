#include <stdio.h>
#include <unistd.h>

int main() {
    int c;
    scanf("%d", &c);
    if (c == 2)
        usleep(500000);
    printf("1 %d\n", c - 1);
}
