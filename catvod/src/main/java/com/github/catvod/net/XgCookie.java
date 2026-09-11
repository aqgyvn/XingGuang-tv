package com.github.catvod.net;

import java.net.HttpCookie;
import java.net.IDN;
import java.util.Locale;

public final class XgCookie {
    private final String name;
    private final String value;
    private final String domain;
    private final String path;
    private final long expiresAt;
    private final boolean secure;
    private final boolean httpOnly;
    private final boolean hostOnly;
    private final boolean persistent;

    public XgCookie(String name, String value, String domain, String path, long expiresAt) {
        this(name, value, domain, path, expiresAt, false, false, false, expiresAt != Long.MAX_VALUE);
    }

    public XgCookie(String name, String value, String domain, String path, long expiresAt,
                    boolean secure, boolean httpOnly, boolean hostOnly, boolean persistent) {
        this.name = name;
        this.value = value;
        this.domain = IDN.toASCII(domain.startsWith(".") ? domain.substring(1) : domain).toLowerCase(Locale.ROOT);
        this.path = path;
        this.expiresAt = expiresAt;
        this.secure = secure;
        this.httpOnly = httpOnly;
        this.hostOnly = hostOnly;
        this.persistent = persistent;
    }

    public String name() { return name; }
    public String value() { return value; }
    public String domain() { return domain; }
    public String path() { return path; }
    public long expiresAt() { return expiresAt; }
    public boolean secure() { return secure; }
    public boolean httpOnly() { return httpOnly; }
    public boolean hostOnly() { return hostOnly; }
    public boolean persistent() { return persistent; }

    public boolean matches(XgUrl url) {
        String host = url.host().toLowerCase(Locale.ROOT);
        boolean domainMatch = host.equals(domain) || (!hostOnly && host.endsWith("." + domain));
        String requestPath = url.encodedPath();
        boolean pathMatch = requestPath.equals(path) || (requestPath.startsWith(path)
                && (path.endsWith("/") || requestPath.charAt(path.length()) == '/'));
        return domainMatch && pathMatch && (!secure || "https".equalsIgnoreCase(url.uri().getScheme()));
    }

    public static XgCookie parse(XgUrl url, String header) {
        try {
            HttpCookie parsed = HttpCookie.parse(header).get(0);
            boolean hostOnly = parsed.getDomain() == null;
            String domain = hostOnly ? url.host() : parsed.getDomain();
            String path = parsed.getPath();
            if (path == null || !path.startsWith("/")) {
                String requestPath = url.encodedPath();
                int lastSlash = requestPath.lastIndexOf('/');
                path = lastSlash <= 0 ? "/" : requestPath.substring(0, lastSlash);
            }
            long age = parsed.getMaxAge();
            long now = System.currentTimeMillis();
            long expires = age < 0 || age > (Long.MAX_VALUE - now) / 1000 ? Long.MAX_VALUE
                    : age == 0 ? Long.MIN_VALUE : now + age * 1000;
            XgCookie cookie = new XgCookie(parsed.getName(), parsed.getValue(), domain, path, expires,
                    parsed.getSecure(), parsed.isHttpOnly(), hostOnly, age >= 0);
            String host = url.host().toLowerCase(Locale.ROOT);
            if (!host.equals(cookie.domain) && !host.endsWith("." + cookie.domain)) return null;
            return cookie;
        } catch (IllegalArgumentException e) {
            return null;
        }
    }
}
