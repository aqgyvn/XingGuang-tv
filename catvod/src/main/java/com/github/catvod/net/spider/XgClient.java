package com.github.catvod.net.spider;

import com.github.catvod.net.XgHttp;

public class XgClient {
    private final boolean redirect;
    private final long timeout;
    private final XgDns dns;
    private final XgCookieJar cookieJar;
    private final XgConnectionPool connectionPool;
    private final javax.net.ssl.SSLSocketFactory sslSocketFactory;
    private final javax.net.ssl.HostnameVerifier hostnameVerifier;
    private final com.github.catvod.net.XgClient delegate;
    public XgClient() { this(true, 30000, null, null, new XgConnectionPool(), null, null); }
    private XgClient(boolean redirect, long timeout, XgDns dns, XgCookieJar cookieJar, XgConnectionPool connectionPool, javax.net.ssl.SSLSocketFactory sslSocketFactory, javax.net.ssl.HostnameVerifier hostnameVerifier) {
        this.redirect = redirect; this.timeout = timeout; this.dns = dns; this.cookieJar = cookieJar; this.connectionPool = connectionPool; this.sslSocketFactory = sslSocketFactory; this.hostnameVerifier = hostnameVerifier;
        delegate = createDelegate();
    }
    public static XgClient client() { return new XgClient(); }
    public XgCall newCall(XgRequest request) { return new XgCallAdapter(delegate, request); }
    private com.github.catvod.net.XgClient createDelegate() {
        com.github.catvod.net.XgDns xgDns = dns == null ? null : new com.github.catvod.net.XgDns() {
            @Override
            public java.util.List<java.net.InetAddress> lookup(String hostname) throws java.io.IOException {
                try {
                    return dns.lookup(hostname);
                } catch (java.net.UnknownHostException error) {
                    throw error;
                }
            }
        };
        com.github.catvod.net.XgCookieJar xgCookieJar = cookieJar == null ? null : new com.github.catvod.net.XgCookieJar() {
            @Override
            public java.util.List<com.github.catvod.net.XgCookie> loadForRequest(com.github.catvod.net.XgUrl url) {
                java.util.List<com.github.catvod.net.XgCookie> result = new java.util.ArrayList<>();
                for (XgCookie cookie : cookieJar.loadForRequest(XgUrl.get(url.toString()))) {
                    if (cookie.delegate.matches(url) && cookie.expiresAt() > System.currentTimeMillis()) result.add(cookie.delegate);
                }
                return result;
            }

            @Override
            public void saveFromResponse(com.github.catvod.net.XgUrl url, java.util.List<com.github.catvod.net.XgCookie> cookies) {
                java.util.List<XgCookie> result = new java.util.ArrayList<>();
                for (com.github.catvod.net.XgCookie cookie : cookies) {
                    result.add(new XgCookie(cookie));
                }
                cookieJar.saveFromResponse(XgUrl.get(url.toString()), result);
            }
        };
        return XgHttp.client(redirect, timeout, xgDns, xgCookieJar, sslSocketFactory, hostnameVerifier);
    }
    public XgConnectionPool connectionPool() { return connectionPool; }
    public Builder newBuilder() {
        return new Builder().followRedirects(redirect).connectTimeout(timeout, java.util.concurrent.TimeUnit.MILLISECONDS)
                .dns(dns).cookieJar(cookieJar).connectionPool(connectionPool)
                .sslSocketFactory(sslSocketFactory).hostnameVerifier(hostnameVerifier);
    }
    public static final class Builder {
        private boolean redirect = true; private long timeout = 30000;
        private XgDns dns; private XgCookieJar cookieJar; private XgConnectionPool connectionPool = new XgConnectionPool(); private javax.net.ssl.SSLSocketFactory sslSocketFactory; private javax.net.ssl.HostnameVerifier hostnameVerifier;
        public Builder followRedirects(boolean value) { redirect = value; return this; }
        public Builder followSslRedirects(boolean value) { return this; }
        public Builder connectTimeout(long value, java.util.concurrent.TimeUnit unit) { timeout = unit.toMillis(value); return this; }
        public Builder readTimeout(long value, java.util.concurrent.TimeUnit unit) { timeout = unit.toMillis(value); return this; }
        public Builder writeTimeout(long value, java.util.concurrent.TimeUnit unit) { timeout = unit.toMillis(value); return this; }
        public Builder dns(XgDns value) { dns = value; return this; }
        public Builder cookieJar(XgCookieJar value) { cookieJar = value; return this; }
        public Builder connectionPool(XgConnectionPool value) { connectionPool = value; return this; }
        public Builder sslSocketFactory(javax.net.ssl.SSLSocketFactory value) { sslSocketFactory = value; return this; }
        public Builder sslSocketFactory(javax.net.ssl.SSLSocketFactory value, javax.net.ssl.X509TrustManager ignored) { sslSocketFactory = value; return this; }
        public Builder hostnameVerifier(javax.net.ssl.HostnameVerifier value) { hostnameVerifier = value; return this; }
        public Builder retryOnConnectionFailure(boolean ignored) { return this; }
        public Builder callTimeout(long value, java.util.concurrent.TimeUnit unit) { timeout = unit.toMillis(value); return this; }
        public XgClient build() { return new XgClient(redirect, timeout, dns, cookieJar, connectionPool, sslSocketFactory, hostnameVerifier); }
    }
    private static final class XgCallAdapter implements XgCall {
        private final com.github.catvod.net.XgCall delegate; private final XgRequest request;
        XgCallAdapter(com.github.catvod.net.XgClient client, XgRequest request) {
            this.request = request;
            com.github.catvod.net.XgHeaders.Builder headers = new com.github.catvod.net.XgHeaders.Builder();
            for (java.util.Map.Entry<String, java.util.List<String>> entry : request.headers().toMultimap().entrySet()) {
                for (String value : entry.getValue()) headers.add(entry.getKey(), value);
            }
            com.github.catvod.net.XgRequest.Builder builder = new com.github.catvod.net.XgRequest.Builder()
                    .url(request.url().toString())
                    .headers(headers.build());
            builder.method(request.method(), request.body() == null ? null : request.body().delegate);
            delegate = client.newCall(builder.build());
        }
        public XgResponse execute() throws java.io.IOException { return new XgResponse(delegate.execute(), request); }
        public XgRequest request() { return request; }
        public void cancel() { delegate.cancel(); }
    }
}
