#include <string.h>
void *memset(void *d,int c,size_t n){unsigned char*p=d;while(n--)*p++=(unsigned char)c;return d;}
void *memcpy(void *d,const void *s,size_t n){unsigned char*p=d;const unsigned char*q=s;while(n--)*p++=*q++;return d;}
void *memmove(void *d,const void *s,size_t n){unsigned char*p=d;const unsigned char*q=s;if(p<q)while(n--)*p++=*q++;else{p+=n;q+=n;while(n--)*--p=*--q;}return d;}
int strcmp(const char*a,const char*b){while(*a&&*a==*b){a++;b++;}return (unsigned char)*a-(unsigned char)*b;}
size_t strlen(const char*s){size_t n=0;while(s[n])n++;return n;}
