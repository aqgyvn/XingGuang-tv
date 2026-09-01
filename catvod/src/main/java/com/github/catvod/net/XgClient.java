package com.github.catvod.net;

import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

public final class XgClient {

    static final class Options {
        final boolean redirect;
        final long timeout;

        Options(boolean redirect, long timeout) {
            this.redirect = redirect;
            this.timeout = timeout;
        }
    }

    private final Options options;
    private final Set<XgCall> calls;

    XgClient(boolean redirect, long timeout) {
        options = new Options(redirect, timeout);
        calls = ConcurrentHashMap.newKeySet();
    }

    public XgCall newCall(XgRequest request) {
        return new XgCall(this, request);
    }

    void register(XgCall call) {
        calls.add(call);
    }

    void unregister(XgCall call) {
        calls.remove(call);
    }

    void cancel(String tag) {
        for (XgCall call : calls) if (tag.equals(call.request().tag())) call.cancel();
    }

    void cancelAll() {
        for (XgCall call : calls) call.cancel();
    }

    Options options() {
        return options;
    }
}
