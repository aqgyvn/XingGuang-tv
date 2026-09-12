package com.github.catvod.net;

import okhttp3.Request;
import okhttp3.Response;
import okhttp3.Route;

/** Original public proxy-authentication ABI. */
public class OkAuthenticator extends XgAuthenticator implements okhttp3.Authenticator {
    @Override
    public Request authenticate(Route route, Response response) {
        if (route == null || response.priorResponse() != null) return null;
        XgRequest request = OkHttpBridge.metadata(response.request());
        XgRequest retry = authenticate(request.url().uri(), route.proxy(), request);
        return retry == null ? null : OkHttpBridge.apply(response.request(), retry);
    }
}
