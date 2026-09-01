package com.fongmi.quickjs.utils;

import com.fongmi.quickjs.bean.Req;
import com.github.catvod.net.XgCall;
import com.github.catvod.net.XgClient;
import com.github.catvod.net.XgFormBody;
import com.github.catvod.net.XgHeaders;
import com.github.catvod.net.XgHttp;
import com.github.catvod.net.XgMultipartBody;
import com.github.catvod.net.XgRequest;
import com.github.catvod.net.XgRequestBody;
import com.github.catvod.net.XgResponse;
import com.github.catvod.utils.Json;
import com.github.catvod.utils.Util;
import com.google.common.net.HttpHeaders;
import com.whl.quickjs.wrapper.JSObject;
import com.whl.quickjs.wrapper.QuickJSContext;

import java.security.SecureRandom;
import java.util.List;
import java.util.Map;

public class Connect {

    public static XgCall to(String url, Req req) {
        XgClient client = XgHttp.xgClient(req.isRedirect(), req.getTimeout());
        return client.newCall(getRequest(url, req, XgHeaders.of(req.getHeader())));
    }

    public static JSObject success(QuickJSContext ctx, Req req, XgResponse res) {
        try (res) {
            JSObject jsObject = ctx.createNewJSObject();
            JSObject jsHeader = ctx.createNewJSObject();
            setHeader(ctx, res, jsHeader);
            jsObject.setProperty("code", res.code());
            jsObject.setProperty("headers", jsHeader);
            if (req.getBuffer() == 0) jsObject.setProperty("content", new String(res.body().bytes(), req.getCharset()));
            if (req.getBuffer() == 1) jsObject.setProperty("content", JSUtil.toArray(ctx, res.body().bytes()));
            if (req.getBuffer() == 2) jsObject.setProperty("content", Util.base64(res.body().bytes()));
            if (req.getBuffer() == 3) jsObject.setProperty("content", res.body().bytes());
            return jsObject;
        } catch (Exception e) {
            return error(ctx);
        }
    }

    public static JSObject error(QuickJSContext ctx) {
        JSObject jsObject = ctx.createNewJSObject();
        JSObject jsHeader = ctx.createNewJSObject();
        jsObject.setProperty("headers", jsHeader);
        jsObject.setProperty("content", "");
        jsObject.setProperty("code", "");
        return jsObject;
    }

    private static XgRequest getRequest(String url, Req req, XgHeaders headers) {
        if (req.getMethod().equalsIgnoreCase("post")) {
            return new XgRequest.Builder().url(url).headers(headers).post(getPostBody(req, headers.get(HttpHeaders.CONTENT_TYPE))).build();
        } else if (req.getMethod().equalsIgnoreCase("header")) {
            return new XgRequest.Builder().url(url).headers(headers).head().build();
        } else {
            return new XgRequest.Builder().url(url).headers(headers).get().build();
        }
    }

    private static XgRequestBody getPostBody(Req req, String contentType) {
        if (req.getData() != null && "json".equals(req.getPostType())) return getJsonBody(req);
        if (req.getData() != null && "form".equals(req.getPostType())) return getFormBody(req);
        if (req.getData() != null && "form-data".equals(req.getPostType())) return getFormDataBody(req);
        if (req.getBody() != null && contentType != null) return XgRequestBody.create(req.getBody(), contentType);
        return XgRequestBody.create(new byte[0]);
    }

    private static XgRequestBody getJsonBody(Req req) {
        return XgRequestBody.create(req.getData().toString(), "application/json; charset=utf-8");
    }

    private static XgRequestBody getFormBody(Req req) {
        XgFormBody.Builder builder = new XgFormBody.Builder();
        Map<String, String> params = Json.toMap(req.getData());
        for (String key : params.keySet()) builder.add(key, params.get(key));
        return builder.build();
    }

    private static XgRequestBody getFormDataBody(Req req) {
        String boundary = "--dio-boundary-" + new SecureRandom().nextInt(42949) + new SecureRandom().nextInt(67296);
        XgMultipartBody.Builder builder = new XgMultipartBody.Builder(boundary);
        Map<String, String> params = Json.toMap(req.getData());
        for (String key : params.keySet()) builder.addFormDataPart(key, params.get(key));
        return builder.build();
    }

    private static void setHeader(QuickJSContext ctx, XgResponse res, JSObject object) {
        for (Map.Entry<String, List<String>> entry : res.headers().toMultimap().entrySet()) {
            if (entry.getValue().size() == 1) object.setProperty(entry.getKey(), entry.getValue().get(0));
            if (entry.getValue().size() >= 2) object.setProperty(entry.getKey(), JSUtil.toArray(ctx, entry.getValue()));
        }
    }
}
