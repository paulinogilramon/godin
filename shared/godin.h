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

/* C function-pointer type: double (*)(double) */
typedef double (*godin_apply_fn)(double);

int         godin_version(void);
int         godin_add(int a, int b);
int         godin_str_len(const char *s);
double      godin_sum(const double *xs, int n);
void        godin_scale(Vec3 *v, double k);
Vec3        godin_make_vec3(double x, double y, double z);

/* Error handling */
double      godin_div(double a, double b);
const char *godin_last_error(void);

/* Callback (Odin calls a Go function pointer) */
double      godin_apply(const double *xs, int n, godin_apply_fn f);

/* Memory ownership (release with godin_free) */
char       *godin_dup(const char *s);
void        godin_free(void *p);

/* Image kernels (RGBA8, caller-owned buffers) --------------------------- */

/*
 * Box blur with arbitrary radius (0 = copy). src, dst and tmp must point to
 * w*h*4 bytes. Edges are clamped. Deterministic: identical results in Go.
 */
void        godin_blur_box_rgba(const unsigned char *src, unsigned char *dst,
                                unsigned char *tmp, int w, int h, int radius);

/*
 * Separable 5x5 Gaussian blur (1,4,6,4,1 / 16). Same buffer requirements.
 */
void        godin_blur_gauss5_rgba(const unsigned char *src, unsigned char *dst,
                                   unsigned char *tmp, int w, int h);

#ifdef __cplusplus
}
#endif

#endif /* GODIN_H */
