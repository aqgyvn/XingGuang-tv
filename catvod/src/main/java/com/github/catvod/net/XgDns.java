package com.github.catvod.net;

import androidx.annotation.NonNull;

import com.github.catvod.bean.Doh;
import com.github.catvod.utils.Util;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.URL;
import java.security.SecureRandom;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

public class XgDns {

    private final ConcurrentHashMap<String, String> map = new ConcurrentHashMap<>();
    private volatile Doh doh;

    public void setDoh(Doh item) {
        if (item == null || item.getUrl().isEmpty()) return;
        doh = item;
    }

    public void clear() {
        map.clear();
        doh = null;
    }

    public void addAll(List<String> hosts) {
        map.putAll(hosts.stream().filter(Objects::nonNull).map(host -> host.split("=", 2)).filter(splits -> splits.length == 2).collect(Collectors.toMap(s -> s[0].trim(), s -> s[1].trim(), (oldHost, newHost) -> newHost)));
    }

    @NonNull
    public List<InetAddress> lookup(@NonNull String hostname) throws IOException {
        String target = get(hostname);
        if (!target.equals(hostname)) return List.of(InetAddress.getByName(target));
        Doh current = doh;
        if (current == null) return List.of(InetAddress.getAllByName(hostname));
        List<InetAddress> result = lookupDoh(current, hostname);
        return result.isEmpty() ? List.of(InetAddress.getAllByName(hostname)) : result;
    }

    private String get(String hostname) {
        String target = map.get(hostname);
        if (target != null) return target;
        for (Map.Entry<String, String> entry : map.entrySet()) if (Util.containOrMatch(hostname, entry.getKey())) return entry.getValue();
        return hostname;
    }

    String mappedHost(String hostname) {
        return get(hostname);
    }

    boolean hasDoh() {
        return doh != null;
    }

    private List<InetAddress> lookupDoh(Doh item, String hostname) throws IOException {
        byte[] query = dnsQuery(hostname);
        String separator = item.getUrl().contains("?") ? "&" : "?";
        String encoded = java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(query);
        URL url = new URL(item.getUrl() + separator + "dns=" + encoded);
        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
        connection.setConnectTimeout(10000);
        connection.setReadTimeout(10000);
        connection.setRequestProperty("Accept", "application/dns-message, application/dns-json");
        connection.setRequestProperty("User-Agent", Util.XGHTTP);
        try {
            if (connection.getResponseCode() / 100 != 2) return List.of();
            byte[] response = readBytes(connection.getInputStream());
            String contentType = connection.getHeaderField("Content-Type");
            if (contentType != null && contentType.toLowerCase(Locale.ROOT).contains("json")) return parseJson(response);
            return parseDns(response);
        } finally {
            connection.disconnect();
        }
    }

    private byte[] dnsQuery(String hostname) throws IOException {
        try (ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            int id = new SecureRandom().nextInt(0x10000);
            output.write((id >> 8) & 0xff);
            output.write(id & 0xff);
            output.write(0x01);
            output.write(0x00);
            output.write(0x00);
            output.write(0x01);
            output.write(0x00);
            output.write(0x00);
            output.write(0x00);
            output.write(0x00);
            for (String label : hostname.split("\\.")) {
                byte[] bytes = label.getBytes(StandardCharsets.US_ASCII);
                output.write(bytes.length);
                output.write(bytes);
            }
            output.write(0);
            output.write(0x00);
            output.write(0x01);
            output.write(0x00);
            output.write(0x01);
            return output.toByteArray();
        }
    }

    private List<InetAddress> parseDns(byte[] bytes) throws IOException {
        if (bytes.length < 12) return List.of();
        int offset = 12;
        offset = skipName(bytes, offset);
        if (offset + 4 > bytes.length) return List.of();
        offset += 4;
        int answers = u16(bytes, 6);
        List<InetAddress> result = new ArrayList<>();
        for (int i = 0; i < answers && offset + 12 <= bytes.length; i++) {
            offset = skipName(bytes, offset);
            if (offset + 10 > bytes.length) break;
            int type = u16(bytes, offset);
            int clazz = u16(bytes, offset + 2);
            int length = u16(bytes, offset + 8);
            offset += 10;
            if (offset + length > bytes.length) break;
            if (type == 1 && clazz == 1 && length == 4) result.add(InetAddress.getByAddress(new byte[]{bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3]}));
            offset += length;
        }
        return result;
    }

    private List<InetAddress> parseJson(byte[] bytes) throws IOException {
        JsonObject json = JsonParser.parseString(new String(bytes, StandardCharsets.UTF_8)).getAsJsonObject();
        JsonArray answers = json.has("Answer") ? json.getAsJsonArray("Answer") : new JsonArray();
        List<InetAddress> result = new ArrayList<>();
        for (JsonElement answer : answers) {
            JsonObject value = answer.getAsJsonObject();
            if (value.has("type") && value.get("type").getAsInt() == 1 && value.has("data")) result.add(InetAddress.getByName(value.get("data").getAsString()));
        }
        return result;
    }

    private int skipName(byte[] bytes, int offset) {
        while (offset < bytes.length) {
            int length = bytes[offset] & 0xff;
            if (length == 0) return offset + 1;
            if ((length & 0xc0) == 0xc0) return offset + 2;
            offset += length + 1;
        }
        return offset;
    }

    private int u16(byte[] bytes, int offset) {
        return ((bytes[offset] & 0xff) << 8) | (bytes[offset + 1] & 0xff);
    }

    private byte[] readBytes(java.io.InputStream input) throws IOException {
        try (ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[4096];
            int count;
            while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
            return output.toByteArray();
        }
    }
}
