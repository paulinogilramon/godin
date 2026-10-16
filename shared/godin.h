#ifndef GODIN_H
#define GODIN_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct Vec3 {
	double x;
	double y;
	double z;
} Vec3;

int    godin_version(void);
int    godin_add(int a, int b);
int    godin_str_len(const char *s);
double godin_sum(const double *xs, int n);
void   godin_scale(Vec3 *v, double k);
Vec3   godin_make_vec3(double x, double y, double z);

#ifdef __cplusplus
}
#endif

#endif /* GODIN_H */
