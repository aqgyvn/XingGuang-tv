package com.github.catvod.net.interceptor;

import com.github.catvod.net.XgRequest;

import java.util.concurrent.ConcurrentHashMap;

public class RequestInterceptor implements okhttp3.Interceptor {

    @Override
    public okhttp3.Response intercept(okhttp3.Interceptor.Chain chain) throws java.io.IOException {
        com.github.catvod.net.XgRequest request = intercept(com.github.catvod.net.OkHttpBridge.metadata(chain.request()));
        return chain.proceed(com.github.catvod.net.OkHttpBridge.apply(chain.request(), request));
    }

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
        // saved is already the raw encoded query value. Re-encoding breaks signed tokens.
        String url = request.url().toString();
        int fragment = url.indexOf('#');
        String suffix = fragment < 0 ? "" : url.substring(fragment);
        if (fragment >= 0) url = url.substring(0, fragment);
        return request.newBuilder().url(url + separator + "auth=" + saved + suffix).build();
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
