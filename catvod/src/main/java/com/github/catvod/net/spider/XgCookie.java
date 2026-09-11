package com.github.catvod.net.spider;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Objects;

public final class XgCookie {
    final com.github.catvod.net.XgCookie delegate;

    XgCookie(com.github.catvod.net.XgCookie delegate) {
        this.delegate = delegate;
    }

    public XgCookie(String name, String value, String domain, String path, long expiresAt) {
        this(new com.github.catvod.net.XgCookie(name, value, domain, path, expiresAt));
    }

    public String name() { return delegate.name(); }
    public String value() { return delegate.value(); }
    public String domain() { return delegate.domain(); }
    public String path() { return delegate.path(); }
    public long expiresAt() { return delegate.expiresAt(); }
    public boolean secure() { return delegate.secure(); }
    public boolean httpOnly() { return delegate.httpOnly(); }
    public boolean hostOnly() { return delegate.hostOnly(); }
    public boolean persistent() { return delegate.persistent(); }

    public boolean matches(XgUrl url) {
        return delegate.matches(com.github.catvod.net.XgUrl.parse(url.toString()));
    }

    public static XgCookie parse(XgUrl url, String header) {
        com.github.catvod.net.XgCookie cookie = com.github.catvod.net.XgCookie.parse(
                com.github.catvod.net.XgUrl.parse(url.toString()), header);
        return cookie == null ? null : new XgCookie(cookie);
    }

    public static List<XgCookie> parseAll(XgUrl url, XgHeaders headers) {
        List<XgCookie> cookies = new ArrayList<>();
        for (String header : headers.values("Set-Cookie")) {
            XgCookie cookie = parse(url, header);
            if (cookie != null) cookies.add(cookie);
        }
        return Collections.unmodifiableList(cookies);
    }

    @Override
    public String toString() {
        return name() + "=" + value();
    }

    public static final class Builder {
        private String name;
        private String value;
        private String domain;
        private String path = "/";
        private long expiresAt = Long.MAX_VALUE;
        private boolean secure;
        private boolean httpOnly;
        private boolean hostOnly;
        private boolean persistent;

        public Builder name(String value) { name = Objects.requireNonNull(value); return this; }
        public Builder value(String value) { this.value = Objects.requireNonNull(value); return this; }
        public Builder domain(String value) { domain = Objects.requireNonNull(value); hostOnly = false; return this; }
        public Builder hostOnlyDomain(String value) { domain = Objects.requireNonNull(value); hostOnly = true; return this; }
        public Builder path(String value) {
            if (value == null || !value.startsWith("/")) throw new IllegalArgumentException("Cookie path must start with /");
            path = value;
            return this;
        }
        public Builder expiresAt(long value) { expiresAt = value <= 0 ? Long.MIN_VALUE : value; persistent = true; return this; }
        public Builder secure() { secure = true; return this; }
        public Builder httpOnly() { httpOnly = true; return this; }

        public XgCookie build() {
            return new XgCookie(new com.github.catvod.net.XgCookie(
                    Objects.requireNonNull(name), Objects.requireNonNull(value), Objects.requireNonNull(domain),
                    path, expiresAt, secure, httpOnly, hostOnly, persistent));
        }
    }
}
