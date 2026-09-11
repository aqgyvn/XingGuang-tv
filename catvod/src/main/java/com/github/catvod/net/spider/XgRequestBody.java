package com.github.catvod.net.spider;

public class XgRequestBody {
    final com.github.catvod.net.XgRequestBody delegate;
    protected XgRequestBody(com.github.catvod.net.XgRequestBody delegate) { this.delegate = delegate; }
    public static XgRequestBody create(XgMediaType type, byte[] content) { return new XgRequestBody(com.github.catvod.net.XgRequestBody.create(content, type == null ? null : type.toString())); }
    public static XgRequestBody create(XgMediaType type, String content) { return new XgRequestBody(com.github.catvod.net.XgRequestBody.create(content, type == null ? null : type.toString())); }
    public XgMediaType contentType() { return delegate.contentType() == null ? null : XgMediaType.parse(delegate.contentType()); }
    public long contentLength() { return delegate.content().length; }
}
