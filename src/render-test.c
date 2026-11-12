#include <OpenGL/OpenGL.h>
#include <dlfcn.h>
#include <stdio.h>
#include <mpv/client.h>
#include <mpv/render_gl.h>
static void *getgl(void *ctx, const char *name) { (void)ctx; return dlsym(RTLD_DEFAULT,name); }
int main(void) {
 CGLPixelFormatAttribute attrs[]={kCGLPFAOpenGLProfile,(CGLPixelFormatAttribute)kCGLOGLPVersion_3_2_Core,(CGLPixelFormatAttribute)0};
 CGLPixelFormatObj fmt=NULL; GLint n=0; CGLContextObj gl=NULL;
 if(CGLChoosePixelFormat(attrs,&fmt,&n)||!fmt||CGLCreateContext(fmt,NULL,&gl)||CGLSetCurrentContext(gl)){fprintf(stderr,"OpenGL context failed\n");return 1;}
 mpv_handle *m=mpv_create(); mpv_request_log_messages(m,"debug"); if(mpv_initialize(m)<0)return 2;
 mpv_opengl_init_params init={.get_proc_address=getgl};
 mpv_render_param p[]={{MPV_RENDER_PARAM_API_TYPE,(void *)MPV_RENDER_API_TYPE_OPENGL},{MPV_RENDER_PARAM_OPENGL_INIT_PARAMS,&init},{0,NULL}};
 mpv_render_context *r=NULL; int e=mpv_render_context_create(&r,m,p);
 for(;;){mpv_event *ev=mpv_wait_event(m,0);if(ev->event_id==MPV_EVENT_NONE)break;if(ev->event_id==MPV_EVENT_LOG_MESSAGE){mpv_event_log_message *x=ev->data;fprintf(stderr,"%s: %s",x->prefix,x->text);}}
 printf("render_context_create=%d (%s)\n",e,mpv_error_string(e));if(r)mpv_render_context_free(r);mpv_terminate_destroy(m);CGLDestroyContext(gl);CGLDestroyPixelFormat(fmt);return e<0?3:0;
}
