package com.github.catvod.net;

import java.util.Locale;

public final class XgRequest {

    private final XgUrl url;
    private final XgHeaders headers;
    private final String method;
    private final XgRequestBody body;
    private final String tag;

    private XgRequest(Builder builder) {
        this.url = XgUrl.require(builder.url);
        this.headers = builder.headers.build();
        this.method = builder.method;
        this.body = builder.body;
        this.tag = builder.tag;
    }

    public XgUrl url() {
        return url;
    }

    public XgHeaders headers() {
        return headers;
    }

    public String method() {
        return method;
    }

    public XgRequestBody body() {
        return body;
    }

    public String tag() {
        return tag;
    }

    public XgRequest newBuilderWithUrl(String url) {
        return newBuilder().url(url).build();
    }

    public Builder newBuilder() {
        return new Builder(this);
    }

    public static final class Builder {

        private String url;
        private XgHeaders.Builder headers;
        private String method;
        private XgRequestBody body;
        private String tag;

        public Builder() {
            headers = new XgHeaders.Builder();
            method = "GET";
        }

        private Builder(XgRequest request) {
            url = request.url.toString();
            headers = request.headers.newBuilder();
            method = request.method;
            body = request.body;
            tag = request.tag;
        }

        public Builder url(String url) {
            this.url = url;
            return this;
        }

        public Builder headers(XgHeaders headers) {
            this.headers = headers == null ? new XgHeaders.Builder() : headers.newBuilder();
            return this;
        }

        public Builder get() {
            return method("GET", null);
        }

        public Builder head() {
            return method("HEAD", null);
        }

        public Builder post(XgRequestBody body) {
            return method("POST", body);
        }

        public Builder method(String method, XgRequestBody body) {
            this.method = method == null ? "GET" : method.toUpperCase(Locale.ROOT);
            this.body = body;
            return this;
        }

        public Builder tag(String tag) {
            this.tag = tag;
            return this;
        }

        public Builder header(String name, String value) {
            headers.set(name, value);
            return this;
        }

        public Builder addHeader(String name, String value) {
            headers.add(name, value);
            return this;
        }

        public XgRequest build() {
            return new XgRequest(this);
        }
    }
}
