#pragma once
#define M_PI 3.14159265358979323846
#define M_PI_2 1.57079632679489661923
#define NAN __builtin_nan("")
#define INFINITY __builtin_inf()
#define isnan(x) __builtin_isnan(x)
#define isfinite(x) __builtin_isfinite(x)
double sin(double); double cos(double); double tan(double); double asin(double); double acos(double); double atan(double); double atan2(double,double);
double exp(double); double log(double); double log10(double); double pow(double,double); double tanh(double); double sinh(double); double cosh(double);
static inline double sqrt(double x){return __builtin_sqrt(x);} static inline double fabs(double x){return __builtin_fabs(x);}
static inline double floor(double x){return __builtin_floor(x);} static inline double ceil(double x){return __builtin_ceil(x);}
static inline double round(double x){return __builtin_round(x);} static inline double fmin(double a,double b){return __builtin_fmin(a,b);}
static inline double fmax(double a,double b){return __builtin_fmax(a,b);} static inline double trunc(double x){return __builtin_trunc(x);}
double fmod(double,double); double exp2(double); double log2(double); double hypot(double,double);
static inline float sinf(float x){return (float)sin(x);} static inline float cosf(float x){return (float)cos(x);} static inline float tanhf(float x){return (float)tanh(x);}
static inline float fabsf(float x){return __builtin_fabsf(x);} static inline float sqrtf(float x){return __builtin_sqrtf(x);}
