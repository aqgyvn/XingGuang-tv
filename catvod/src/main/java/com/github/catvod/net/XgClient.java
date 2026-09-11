package com.github.catvod.net;

import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.SSLSocketFactory;

public final class XgClient {

    static final class Options {
        final boolean redirect;
        final long timeout;
        final XgDns dns;
        final XgCookieJar cookieJar;
        final SSLSocketFactory sslSocketFactory;
        final HostnameVerifier hostnameVerifier;

        Options(boolean redirect, long timeout, XgDns dns, XgCookieJar cookieJar, SSLSocketFactory sslSocketFactory, HostnameVerifier hostnameVerifier) {
            this.redirect = redirect;
            this.timeout = timeout;
            this.dns = dns == null ? XgHttp.dns() : dns;
            this.cookieJar = cookieJar == null ? XgCookieJar.NO_COOKIES : cookieJar;
            this.sslSocketFactory = sslSocketFactory;
            this.hostnameVerifier = hostnameVerifier;
        }
    }

    private final Options options;
    private final Set<XgCall> calls;

    XgClient(boolean redirect, long timeout) {
        this(redirect, timeout, null, null, null, null);
    }

    XgClient(boolean redirect, long timeout, XgDns dns, XgCookieJar cookieJar, SSLSocketFactory sslSocketFactory, HostnameVerifier hostnameVerifier) {
        options = new Options(redirect, timeout, dns, cookieJar, sslSocketFactory, hostnameVerifier);
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
