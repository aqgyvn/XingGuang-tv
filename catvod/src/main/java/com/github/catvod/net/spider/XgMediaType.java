package com.github.catvod.net.spider;

public final class XgMediaType {
    private final String value;
    private XgMediaType(String value) { this.value = value == null ? "" : value; }
    public static XgMediaType parse(String value) { return value == null ? null : new XgMediaType(value); }
    public String toString() { return value; }
}
