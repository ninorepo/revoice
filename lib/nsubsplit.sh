#!/bin/bash

INPUT="$1"
MAX="$2"

gawk -v MAX="$MAX" '

function t2ms(t, a) {
    split(t, a, /[:,]/)
    return (((a[1]*3600)+(a[2]*60)+a[3])*1000)+a[4]
}

function ms2t(ms, h,m,s,x) {

    h=int(ms/3600000)
    ms%=3600000

    m=int(ms/60000)
    ms%=60000

    s=int(ms/1000)
    x=ms%1000

    return sprintf("%02d:%02d:%02d,%03d",h,m,s,x)
}

BEGIN{
    out=1
}

# subtitle number
/^[0-9]+$/{
    getline timeLine
    split(timeLine, tt, " --> ")

    start=tt[1]
    end=tt[2]

    text=""

    while(getline > 0){

        if($0=="")
            break

        if(text!="")
            text=text" "

        text=text$0
    }

    n=split(text,w,/ +/)

    s=t2ms(start)
    e=t2ms(end)

    dur=e-s

    cur=s

    for(i=1;i<=n;){

        chunk=""
        cnt=0

        while(i<=n && cnt<MAX){

            if(chunk!="")
                chunk=chunk" "

            chunk=chunk w[i]

            i++
            cnt++
        }

        nxt=cur+int(dur*(cnt/n))

        if(i>n)
            nxt=e

        print out++
        print ms2t(cur)" --> "ms2t(nxt)
        print chunk
        print ""

        cur=nxt
    }
}
' "$INPUT"

