package com.github.catvod.net.spider;

import java.util.UUID;

public final class XgMultipartBody extends XgRequestBody {
    public static final XgMediaType FORM = XgMediaType.parse("multipart/form-data");
    private XgMultipartBody(com.github.catvod.net.XgMultipartBody body) { super(body); }
    public static final class Builder {
        private final com.github.catvod.net.XgMultipartBody.Builder delegate = new com.github.catvod.net.XgMultipartBody.Builder(UUID.randomUUID().toString());
        public Builder setType(XgMediaType type) { return this; }
        public Builder addFormDataPart(String name, String value) { delegate.addFormDataPart(name, value); return this; }
        public XgMultipartBody build() { return new XgMultipartBody(delegate.build()); }
    }
}
