package goencoding;

import klava.Locality;

class SendReq {
    public Object msg;
    public Locality sender;

    public SendReq(Object msg, Locality sender) {
        this.msg = msg;
        this.sender = sender;
    }
}