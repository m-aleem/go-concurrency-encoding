package goencoding;

import klava.Locality;

class RecvReq {
    public Locality receiver;
    public Object tag;

    public RecvReq(Locality receiver, Object tag) {
        this.receiver = receiver;
        this.tag = tag;
    }
}
