#include <OpenGL/OpenGL.h>
#include <stdio.h>
#include <execinfo.h>
#include <string.h>
#include <stdlib.h>
static CGLError force_core(const CGLPixelFormatAttribute *attrs,CGLPixelFormatObj *out,GLint *count) {
 void *frames[32]; int depth=backtrace(frames,32), target=0; char **symbols=backtrace_symbols(frames,depth); if(symbols){for(int k=0;k<depth;k++) if(strstr(symbols[k],"SetOpenGLViewState") || strstr(symbols[k],"CreateOpenGLView")) target=1;free(symbols);} if(!target) return CGLChoosePixelFormat(attrs,out,count);
 CGLPixelFormatAttribute copy[256]; int i=0,j=0,has=0;
 while(attrs[i] && i<240 && j<240){CGLPixelFormatAttribute a=attrs[i++];copy[j++]=a; if(a==kCGLPFAOpenGLProfile){copy[j++]=(CGLPixelFormatAttribute)kCGLOGLPVersion_3_2_Core;i++;has=1;}else if(a==kCGLPFAColorSize||a==kCGLPFAAlphaSize||a==kCGLPFADepthSize||a==kCGLPFAStencilSize||a==kCGLPFAAccumSize||a==kCGLPFASampleBuffers||a==kCGLPFASamples||a==kCGLPFARendererID||a==kCGLPFADisplayMask||a==kCGLPFAVirtualScreenCount||a==kCGLPFAAuxBuffers){copy[j++]=attrs[i++];}}
 if(!has){copy[j++]=kCGLPFAOpenGLProfile;copy[j++]=(CGLPixelFormatAttribute)kCGLOGLPVersion_3_2_Core;}copy[j]=0;
 CGLError e=CGLChoosePixelFormat(copy,out,count);if(e){fprintf(stderr,"DV test: core profile request failed (%d), using original\n",e);return CGLChoosePixelFormat(attrs,out,count);}fprintf(stderr,"DV test: requested OpenGL core profile\n");return e;
}
__attribute__((used)) static struct {const void *replacement;const void *original;} interpose[] __attribute__((section("__DATA,__interpose")))={{(const void *)force_core,(const void *)CGLChoosePixelFormat}};
