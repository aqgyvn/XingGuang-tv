package com.github.catvod.net.spider;

public final class XgFormBody extends XgRequestBody {
    private XgFormBody(com.github.catvod.net.XgFormBody body) { super(body); }
    public static final class Builder {
        private final com.github.catvod.net.XgFormBody.Builder delegate = new com.github.catvod.net.XgFormBody.Builder();
        public Builder add(String name, String value) { delegate.add(name, value); return this; }
        public Builder addEncoded(String name, String value) {
            return add(java.net.URLDecoder.decode(name, java.nio.charset.StandardCharsets.UTF_8),
                    java.net.URLDecoder.decode(value, java.nio.charset.StandardCharsets.UTF_8));
        }
        public XgFormBody build() { return new XgFormBody(delegate.build()); }
    }
}
