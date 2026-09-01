package com.github.catvod.net;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;

public class XgRequestBody {

    private final byte[] content;
    private final String contentType;

    XgRequestBody(byte[] content, String contentType) {
        this.content = content == null ? new byte[0] : Arrays.copyOf(content, content.length);
        this.contentType = contentType;
    }

    public static XgRequestBody create(byte[] content) {
        return new XgRequestBody(content, null);
    }

    public static XgRequestBody create(String content, String contentType) {
        return new XgRequestBody(content == null ? new byte[0] : content.getBytes(StandardCharsets.UTF_8), contentType);
    }

    byte[] content() {
        return content;
    }

    String contentType() {
        return contentType;
    }
}
