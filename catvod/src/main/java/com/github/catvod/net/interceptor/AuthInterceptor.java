package com.github.catvod.net.interceptor;

import com.github.catvod.net.XgRequest;
import com.github.catvod.utils.Util;
import com.google.common.net.HttpHeaders;

import java.net.URI;
import java.util.concurrent.ConcurrentHashMap;

public class AuthInterceptor implements okhttp3.Interceptor {

    @Override
    public okhttp3.Response intercept(okhttp3.Interceptor.Chain chain) throws java.io.IOException {
        com.github.catvod.net.XgRequest request = intercept(com.github.catvod.net.OkHttpBridge.metadata(chain.request()));
        return chain.proceed(com.github.catvod.net.OkHttpBridge.apply(chain.request(), request));
    }

    private final ConcurrentHashMap<String, String> userMap = new ConcurrentHashMap<>();

    public void clear() {
        userMap.clear();
    }

    public XgRequest intercept(XgRequest request) {
        URI uri = request.url().uri();
        String user = uri.getUserInfo();
        if (user == null) return request;
        userMap.put(request.url().host(), user);
        return request.newBuilder().header(HttpHeaders.AUTHORIZATION, Util.basic(user)).build();
    }

    public XgRequest authenticate(XgRequest request, String challenge) {
        if (request.headers().get(HttpHeaders.AUTHORIZATION) != null && request.url().uri().getUserInfo() == null) return null;
        String user = request.url().uri().getUserInfo();
        if (user == null) user = userMap.get(request.url().host());
        if (user == null) return null;
        String header = challenge != null && challenge.startsWith("Digest") ? Util.digest(user, challenge, request) : Util.basic(user);
        return request.newBuilder().header(HttpHeaders.AUTHORIZATION, header).build();
    }
}
