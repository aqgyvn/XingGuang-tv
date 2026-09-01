package com.github.catvod.net.interceptor;

import com.github.catvod.net.XgRequest;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ConcurrentHashMap;

public class RequestInterceptor {

    private final ConcurrentHashMap<String, String> authMap = new ConcurrentHashMap<>();

    public void clear() {
        authMap.clear();
    }

    public XgRequest intercept(XgRequest request) {
        String host = request.url().host();
        String query = request.url().uri().getRawQuery();
        String auth = queryValue(query, "auth");
        if (auth != null) {
            authMap.put(host, auth);
            return request;
        }
        String saved = authMap.get(host);
        if (saved == null) return request;
        String separator = query == null || query.isEmpty() ? "?" : "&";
        return request.newBuilder().url(request.url() + separator + "auth=" + URLEncoder.encode(saved, StandardCharsets.UTF_8)).build();
    }

    private String queryValue(String query, String name) {
        if (query == null || query.isEmpty()) return null;
        for (String item : query.split("&")) {
            int index = item.indexOf('=');
            String key = index < 0 ? item : item.substring(0, index);
            if (name.equals(key)) return index < 0 ? "" : item.substring(index + 1);
        }
        return null;
    }
}
