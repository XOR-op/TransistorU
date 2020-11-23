#!/usr/bin/python3
import re
import sys
import os
import subprocess as sp
#if len(sys.argv)!=2:
#    print('ERR: wrong size')
#    exit(0)
#filename=sys.argv[1]
with open('./test/test.c','r') as f:
    code=str(f.read())
    code=code.replace('"io.h"','<stdio.h>')
    code=re.sub('outb\(','printf("%c",',code)
    code=re.sub('outlln\(',r'printf("%d\\n",',code)
    code=re.sub('outl\(',r'printf("%d",',code)
    code=re.sub('println\(',r'printf("%s\\n",',code)
    code=re.sub('print\(',r'printf("%s",',code)

    with open('./test/testx64.c','w') as out:
        out.write(code)
sp.call('g++ ./test/testx64.c -o ./test/x64.out&&./test/x64.out>./test/x64.ans',shell=True)

