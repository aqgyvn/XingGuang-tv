package com.github.catvod.net.spider;

import java.util.Base64;
import java.nio.charset.StandardCharsets;

public final class XgCredentials {
    private XgCredentials() {}
    public static String basic(String userName, String password) {
        return "Basic " + Base64.getEncoder().encodeToString((userName + ":" + password).getBytes(StandardCharsets.ISO_8859_1));
    }
}
