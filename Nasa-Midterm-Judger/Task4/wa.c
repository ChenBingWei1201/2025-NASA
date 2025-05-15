#include <stdio.h>

int main() {
    long long H, W;
    scanf("%lld%lld", &H, &W);
    if (H == 2)
        puts("haha i'm going to get a wrong answer");
    printf("%lld\n", (H-1)*(H-2)/2 + (W-1)*(W-2)/2 + (W-1)*(H-1)*4);
}
