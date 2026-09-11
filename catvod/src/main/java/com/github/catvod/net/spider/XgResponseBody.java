package com.github.catvod.net.spider;

import java.io.InputStream;
import java.io.IOException;

public class XgResponseBody implements AutoCloseable {
    private final com.github.catvod.net.XgResponseBody delegate;
    XgResponseBody(com.github.catvod.net.XgResponseBody delegate) { this.delegate = delegate; }
    public byte[] bytes() throws IOException { return delegate.bytes(); }
    public String string() throws IOException { return delegate.string(); }
    public InputStream byteStream() { return delegate.byteStream(); }
    public long contentLength() { return delegate.contentLength(); }
    public XgMediaType contentType() { return delegate.contentType() == null ? null : XgMediaType.parse(delegate.contentType()); }
    public void close() { try { delegate.close(); } catch (IOException ignored) {} }
}
