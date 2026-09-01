package com.github.catvod.crawler;

import android.content.Context;

import com.github.catvod.net.XgClient;
import com.github.catvod.net.XgDns;
import com.github.catvod.net.XgHttp;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

public abstract class Spider {

    public String siteKey;

    public void init(Context context) throws Exception {
    }

    public void init(Context context, String extend) throws Exception {
        init(context);
    }

    public String homeContent(boolean filter) throws Exception {
        return "";
    }

    public String homeVideoContent() throws Exception {
        return "";
    }

    public String categoryContent(String tid, String pg, boolean filter, HashMap<String, String> extend) throws Exception {
        return "";
    }

    public String detailContent(List<String> ids) throws Exception {
        return "";
    }

    public String searchContent(String key, boolean quick) throws Exception {
        return "";
    }

    public String searchContent(String key, boolean quick, String pg) throws Exception {
        return "";
    }

    public String playerContent(String flag, String id, List<String> vipFlags) throws Exception {
        return "";
    }

    public String liveContent(String url) throws Exception {
        return "";
    }

    public boolean manualVideoCheck() throws Exception {
        return false;
    }

    public boolean isVideoFormat(String url) throws Exception {
        return false;
    }

    public Object[] proxy(Map<String, String> params) throws Exception {
        return null;
    }

    public String action(String action) throws Exception {
        return null;
    }

    public void destroy() {
    }

    public static XgDns safeDns() {
        return XgHttp.dns();
    }

    public static XgClient client() {
        return XgHttp.client();
    }
}
