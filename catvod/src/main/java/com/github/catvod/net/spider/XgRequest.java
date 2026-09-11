package com.github.catvod.net.spider;

import java.util.Locale;

public final class XgRequest {
    private final XgUrl url;
    private final XgHeaders headers;
    private final String method;
    private final XgRequestBody body;
    private XgRequest(Builder builder) { url = builder.url; headers = builder.headers.build(); method = builder.method; body = builder.body; }
    public XgUrl url() { return url; }
    public XgHeaders headers() { return headers; }
    public String method() { return method; }
    public XgRequestBody body() { return body; }
    public Builder newBuilder() { return new Builder(this); }
    public static final class Builder {
        private XgUrl url;
        private XgHeaders.Builder headers = new XgHeaders.Builder();
        private String method = "GET";
        private XgRequestBody body;
        public Builder() {}
        private Builder(XgRequest request) { url = request.url; headers = request.headers.newBuilder(); method = request.method; body = request.body; }
        public Builder url(String value) { url = XgUrl.get(value); return this; }
        public Builder url(XgUrl value) { url = value; return this; }
        public Builder headers(XgHeaders value) { headers = value == null ? new XgHeaders.Builder() : value.newBuilder(); return this; }
        public Builder header(String name, String value) { headers.set(name, value); return this; }
        public Builder addHeader(String name, String value) { headers.add(name, value); return this; }
        public Builder get() { return method("GET", null); }
        public Builder head() { return method("HEAD", null); }
        public Builder post(XgRequestBody value) { return method("POST", value); }
        public Builder put(XgRequestBody value) { return method("PUT", value); }
        public Builder method(String value, XgRequestBody content) { method = value == null ? "GET" : value.toUpperCase(Locale.ROOT); body = content; return this; }
        public XgRequest build() { if (url == null) throw new IllegalStateException("url == null"); return new XgRequest(this); }
    }
}
