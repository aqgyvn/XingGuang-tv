package com.github.catvod.net.migration;

import com.android.tools.smali.dexlib2.iface.reference.MethodReference;
import com.android.tools.smali.dexlib2.immutable.reference.ImmutableMethodReference;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

final class SpiderNetworkTypes {
    static final String LEGACY = "Lokhttp3/";
    static final String OWNED = "Lcom/github/catvod/net/spider/";
    private static final String LEGACY_DAV = "Lcom/thegrizzlylabs/sardineandroid/";
    private static final String OWNED_DAV = "Lcom/github/catvod/net/webdav/";
    private static final Map<String, String> TYPES = types();

    private SpiderNetworkTypes() {}

    private static Map<String, String> types() {
        Map<String, String> result = new LinkedHashMap<>();
        String[] names = {"Call", "ConnectionPool", "Cookie", "CookieJar", "Credentials", "Dns",
                "FormBody", "Headers", "HttpUrl", "MediaType", "MultipartBody", "OkHttpClient",
                "Request", "RequestBody", "Response", "ResponseBody"};
        for (String name : names) {
            String target = name.equals("OkHttpClient") ? "Client" : name.equals("HttpUrl") ? "Url" : name;
            result.put(LEGACY + name + ";", OWNED + "Xg" + target + ";");
        }
        for (String name : new String[]{"Cookie", "FormBody", "Headers", "HttpUrl", "MultipartBody", "OkHttpClient", "Request"}) {
            String target = result.get(LEGACY + name + ";");
            result.put(LEGACY + name + "$Builder;", target.substring(0, target.length() - 1) + "$Builder;");
        }
        result.put(LEGACY_DAV + "Sardine;", OWNED_DAV + "XgWebDav;");
        result.put(LEGACY_DAV + "DavResource;", OWNED_DAV + "XgDavResource;");
        result.put(LEGACY_DAV + "impl/OkHttpSardine;", OWNED_DAV + "XgWebDavClient;");
        return Collections.unmodifiableMap(result);
    }

    static String rewrite(String type) {
        int dimensions = 0;
        while (dimensions < type.length() && type.charAt(dimensions) == '[') dimensions++;
        String unwrapped = type.substring(dimensions);
        return type.substring(0, dimensions) + TYPES.getOrDefault(unwrapped, unwrapped);
    }

    static boolean legacy(String type) {
        return type.contains(LEGACY) || type.contains(LEGACY_DAV);
    }

    static String rewriteString(String value) {
        for (Map.Entry<String, String> entry : TYPES.entrySet()) {
            if (value.equals(binaryName(entry.getKey()))) return binaryName(entry.getValue());
            if (value.equals(entry.getKey().substring(1, entry.getKey().length() - 1))) {
                return entry.getValue().substring(1, entry.getValue().length() - 1);
            }
        }
        // DEX generic signatures may contain multiple descriptors in one string.
        if (value.startsWith("L") || value.startsWith("[")) {
            for (Map.Entry<String, String> entry : TYPES.entrySet()) value = value.replace(entry.getKey(), entry.getValue());
        }
        return value;
    }

    static String binaryName(String descriptor) {
        return descriptor.substring(1, descriptor.length() - 1).replace('/', '.');
    }

    static MethodReference hostBridge(MethodReference method) {
        if (!method.getDefiningClass().equals("Lcom/github/catvod/crawler/Spider;")
                || !method.getParameterTypes().isEmpty()) return method;
        String owner = null;
        if (method.getName().equals("client") && method.getReturnType().equals(LEGACY + "OkHttpClient;")) owner = OWNED + "XgClient;";
        if (method.getName().equals("safeDns") && method.getReturnType().equals(LEGACY + "Dns;")) owner = OWNED + "XgDns;";
        return owner == null ? method : new ImmutableMethodReference(owner, method.getName(),
                Collections.emptyList(), rewrite(method.getReturnType()));
    }
}
