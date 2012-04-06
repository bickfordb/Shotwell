//#ifndef _AES_H
//#define _AES_H
//
//#ifndef uint8
//#define uint8  unsigned char
//#endif
//
//#ifndef uint32
//#define uint32 unsigned long int
//#endif
//
//typedef struct
//{
//    uint32 erk[64];     /* encryption round keys */
//    uint32 drk[64];     /* decryption round keys */
//    int nr;             /* number of rounds */
//}
//aes_context;
//
//int  aes_set_key( aes_context *ctx, uint8 *key, int nbits );
//void aes_encrypt( aes_context *ctx, uint8 input[16], uint8 output[16] );
//void aes_decrypt( aes_context *ctx, uint8 input[16], uint8 output[16] );
//
//#endif /* aes.h */
//
//
///*
// * Copyright (c) 1995, 1996, 1997 Kungliga Tekniska Högskolan
// * (Royal Institute of Technology, Stockholm, Sweden).
// * All rights reserved.
// * 
// * Redistribution and use in source and binary forms, with or without
// * modification, are permitted provided that the following conditions
// * are met:
// * 
// * 1. Redistributions of source code must retain the above copyright
// *    notice, this list of conditions and the following disclaimer.
// * 
// * 2. Redistributions in binary form must reproduce the above copyright
// *    notice, this list of conditions and the following disclaimer in the
// *    documentation and/or other materials provided with the distribution.
// * 
// * 3. Neither the name of the Institute nor the names of its contributors
// *    may be used to endorse or promote products derived from this software
// *    without specific prior written permission.
// * 
// * THIS SOFTWARE IS PROVIDED BY THE INSTITUTE AND CONTRIBUTORS ``AS IS'' AND
// * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// * ARE DISCLAIMED.  IN NO EVENT SHALL THE INSTITUTE OR CONTRIBUTORS BE LIABLE
// * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
// * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
// * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
// * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
// * SUCH DAMAGE.
// */
//
///* $Id: base64.h,v 1.1.1.1 2005/07/23 13:57:04 shiro Exp $ */
//
//#ifndef _BASE64_H_
//#define _BASE64_H_
//
//int base64_encode(const void *data, int size, char **str);
//int base64_decode(const char *str, void *data);
//
//#endif
