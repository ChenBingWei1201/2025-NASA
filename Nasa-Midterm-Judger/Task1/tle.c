#include <stdio.h>

int main() {
    long long a, b;
    scanf("%lld%lld", &a, &b);
    while (b--)
        ++a;
    printf("%lld\n", a);
}
