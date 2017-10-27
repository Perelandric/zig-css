#ifndef _35__0_PARSING_H
#define _35__0_PARSING_H


#ifdef __cplusplus
#define _35__0_PARSING_EXTERN_C extern "C"
#else
#define _35__0_PARSING_EXTERN_C
#endif

#if defined(_WIN32)
#define _35__0_PARSING_EXPORT _35__0_PARSING_EXTERN_C __declspec(dllimport)
#else
#define _35__0_PARSING_EXPORT _35__0_PARSING_EXTERN_C __attribute__((visibility ("default")))
#endif


#endif
